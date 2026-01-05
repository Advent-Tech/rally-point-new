import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/delivery_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/local_storage.dart';

part 'delivery_event.dart';
part 'delivery_state.dart';

class DeliveryBloc extends Bloc<DeliveryEvent, DeliveryState> {
  ApiClient? _apiClient;
  LocalStorage? _localStorage;
  bool _isInitialized = false;

  DeliveryBloc() : super(DeliveryInitial()) {
    on<DeliveryLoadList>(_onLoadList);
    on<DeliveryLoadDetail>(_onLoadDetail);
    on<DeliveryCreate>(_onCreate);
    on<DeliveryUpdateStatus>(_onUpdateStatus);
    on<DeliveryLoadRoutes>(_onLoadRoutes);
    on<DeliveryStartRoute>(_onStartRoute);
    on<DeliveryCompleteDelivery>(_onCompleteDelivery);
    on<DeliveryFailDelivery>(_onFailDelivery);
    on<DeliveryRefresh>(_onRefresh);
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _apiClient = await ApiClient.getInstance();
    _localStorage = await LocalStorage.getInstance();
    _isInitialized = true;
  }

  Future<void> _onLoadList(
    DeliveryLoadList event,
    Emitter<DeliveryState> emit,
  ) async {
    emit(DeliveryLoading());

    try {
      await _initialize();

      // Get user's worker_id from stored user data
      final userData = _localStorage?.getUserData();
      final workerId = userData?['id'] ?? userData?['worker_id'];

      if (workerId == null) {
        // No worker ID available, return empty list
        emit(const DeliveryListLoaded(
          deliveries: [],
          pendingCount: 0,
          completedCount: 0,
          failedCount: 0,
          hasMore: false,
        ));
        return;
      }

      // Use worker-specific endpoint: /api/workers/:workerId/deliveries
      final response = await _apiClient!.get(
        '${ApiConstants.workerDeliveries}/$workerId/deliveries',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List
            ? response.data
            : response.data['deliveries'] ?? [];
        // Each item is { "delivery": {...}, "items": [...] }, extract the delivery
        final deliveries = data.map((json) {
          final deliveryData = json['delivery'] ?? json;
          return DeliveryModel.fromJson(deliveryData);
        }).toList();

        // Cache the flat delivery data for offline
        final flatData = data.map((json) => json['delivery'] ?? json).toList();
        await _localStorage?.saveDeliveries(flatData);

        emit(DeliveryListLoaded(
          deliveries: deliveries,
          pendingCount: deliveries.where((d) => d.isPending).length,
          completedCount: deliveries.where((d) => d.isCompleted).length,
          failedCount: deliveries.where((d) => d.isFailed).length,
          hasMore: false,
        ));
      } else {
        // Return empty list on error
        emit(const DeliveryListLoaded(
          deliveries: [],
          pendingCount: 0,
          completedCount: 0,
          failedCount: 0,
          hasMore: false,
        ));
      }
    } catch (e) {
      // Try loading from cache if available
      final cached = _localStorage?.getDeliveries();
      if (cached != null && cached.isNotEmpty) {
        final deliveries = cached.map((json) => DeliveryModel.fromJson(json)).toList();
        emit(DeliveryListLoaded(
          deliveries: deliveries,
          pendingCount: deliveries.where((d) => d.isPending).length,
          completedCount: deliveries.where((d) => d.isCompleted).length,
          failedCount: deliveries.where((d) => d.isFailed).length,
          hasMore: false,
          isOffline: true,
        ));
      } else {
        // Return empty state instead of error
        emit(const DeliveryListLoaded(
          deliveries: [],
          pendingCount: 0,
          completedCount: 0,
          failedCount: 0,
          hasMore: false,
        ));
      }
    }
  }

  Future<void> _onLoadDetail(
    DeliveryLoadDetail event,
    Emitter<DeliveryState> emit,
  ) async {
    emit(DeliveryLoading());

    try {
      await _initialize();

      final response = await _apiClient!.get('${ApiConstants.deliveries}/${event.id}');

      if (response.statusCode == 200) {
        // Backend returns { "delivery": {...}, "items": [...] }
        final deliveryData = response.data['delivery'] ?? response.data;
        final delivery = DeliveryModel.fromJson(deliveryData);
        emit(DeliveryDetailLoaded(delivery: delivery));
      } else {
        emit(DeliveryError(message: 'Failed to load delivery details'));
      }
    } catch (e) {
      emit(DeliveryError(message: e.toString()));
    }
  }

  Future<void> _onCreate(
    DeliveryCreate event,
    Emitter<DeliveryState> emit,
  ) async {
    emit(DeliverySubmitting());

    try {
      await _initialize();

      final response = await _apiClient!.post(
        ApiConstants.deliveriesCreate,
        data: event.request.toJson(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Backend returns { "delivery": {...}, "items": [...] }
        final deliveryData = response.data['delivery'] ?? response.data;
        final delivery = DeliveryModel.fromJson(deliveryData);
        emit(DeliveryCreateSuccess(delivery: delivery));
        // Reload list
        add(const DeliveryLoadList());
      } else {
        emit(DeliveryError(message: 'Failed to create delivery'));
      }
    } catch (e) {
      emit(DeliveryError(message: e.toString()));
    }
  }

  Future<void> _onUpdateStatus(
    DeliveryUpdateStatus event,
    Emitter<DeliveryState> emit,
  ) async {
    emit(DeliveryUpdating());

    try {
      await _initialize();

      final response = await _apiClient!.put(
        '${ApiConstants.deliveries}/${event.deliveryId}/status',
        data: event.request.toJson(),
      );

      if (response.statusCode == 200) {
        // Status update returns {"message": "..."}, not a delivery
        // Reload the list to get updated data
        add(const DeliveryLoadList());
      } else {
        emit(DeliveryError(message: 'Failed to update delivery status'));
      }
    } catch (e) {
      emit(DeliveryError(message: e.toString()));
    }
  }

  Future<void> _onLoadRoutes(
    DeliveryLoadRoutes event,
    Emitter<DeliveryState> emit,
  ) async {
    emit(DeliveryLoading());

    try {
      await _initialize();

      final response = await _apiClient!.get(
        ApiConstants.routes,
        queryParameters: {
          if (event.status != null) 'status': event.status,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is List
            ? response.data
            : response.data['routes'] ?? [];
        final routes = data.map((json) => DeliveryRoute.fromJson(json)).toList();

        emit(DeliveryRoutesLoaded(routes: routes));
      } else {
        emit(DeliveryError(message: 'Failed to load routes'));
      }
    } catch (e) {
      emit(DeliveryError(message: e.toString()));
    }
  }

  Future<void> _onStartRoute(
    DeliveryStartRoute event,
    Emitter<DeliveryState> emit,
  ) async {
    emit(DeliveryUpdating());

    try {
      await _initialize();

      final response = await _apiClient!.post(
        '${ApiConstants.routes}/${event.routeId}/start',
      );

      if (response.statusCode == 200) {
        emit(DeliveryRouteStarted(routeId: event.routeId));
        // Reload routes
        add(const DeliveryLoadRoutes());
      } else {
        emit(DeliveryError(message: 'Failed to start route'));
      }
    } catch (e) {
      emit(DeliveryError(message: e.toString()));
    }
  }

  Future<void> _onCompleteDelivery(
    DeliveryCompleteDelivery event,
    Emitter<DeliveryState> emit,
  ) async {
    emit(DeliveryUpdating());

    try {
      await _initialize();

      final response = await _apiClient!.post(
        '${ApiConstants.deliveries}/${event.deliveryId}/complete',
        data: {
          if (event.signatureUrl != null) 'signature_url': event.signatureUrl,
          if (event.photoUrl != null) 'photo_url': event.photoUrl,
          if (event.notes != null) 'notes': event.notes,
        },
      );

      if (response.statusCode == 200) {
        // Backend returns {"message": "..."}, reload list to get updated data
        add(const DeliveryLoadList());
      } else {
        emit(DeliveryError(message: 'Failed to complete delivery'));
      }
    } catch (e) {
      emit(DeliveryError(message: e.toString()));
    }
  }

  Future<void> _onFailDelivery(
    DeliveryFailDelivery event,
    Emitter<DeliveryState> emit,
  ) async {
    emit(DeliveryUpdating());

    try {
      await _initialize();

      final response = await _apiClient!.post(
        '${ApiConstants.deliveries}/${event.deliveryId}/fail',
        data: {
          'failure_reason': event.reason,
          if (event.photoUrl != null) 'photo_url': event.photoUrl,
        },
      );

      if (response.statusCode == 200) {
        // Backend returns {"message": "..."}, reload list to get updated data
        add(const DeliveryLoadList());
      } else {
        emit(DeliveryError(message: 'Failed to record delivery failure'));
      }
    } catch (e) {
      emit(DeliveryError(message: e.toString()));
    }
  }

  Future<void> _onRefresh(
    DeliveryRefresh event,
    Emitter<DeliveryState> emit,
  ) async {
    add(const DeliveryLoadList());
  }
}
