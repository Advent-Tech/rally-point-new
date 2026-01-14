import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/blog_model.dart';
import '../../../data/repositories/blog_repository.dart';

// Events
abstract class BlogEvent extends Equatable {
  const BlogEvent();

  @override
  List<Object?> get props => [];
}

class BlogLoadList extends BlogEvent {
  final int page;
  final int pageSize;
  final bool refresh;

  const BlogLoadList({
    this.page = 1,
    this.pageSize = 10,
    this.refresh = false,
  });

  @override
  List<Object?> get props => [page, pageSize, refresh];
}

class BlogLoadMore extends BlogEvent {
  const BlogLoadMore();
}

class BlogLoadDetail extends BlogEvent {
  final String blogId;

  const BlogLoadDetail({required this.blogId});

  @override
  List<Object?> get props => [blogId];
}

class BlogRefresh extends BlogEvent {
  const BlogRefresh();
}

// States
abstract class BlogState extends Equatable {
  const BlogState();

  @override
  List<Object?> get props => [];
}

class BlogInitial extends BlogState {
  const BlogInitial();
}

class BlogLoading extends BlogState {
  const BlogLoading();
}

class BlogListLoaded extends BlogState {
  final List<BlogModel> blogs;
  final int currentPage;
  final int totalPages;
  final bool hasMore;
  final bool isLoadingMore;

  const BlogListLoaded({
    required this.blogs,
    required this.currentPage,
    required this.totalPages,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  @override
  List<Object?> get props => [blogs, currentPage, totalPages, hasMore, isLoadingMore];

  BlogListLoaded copyWith({
    List<BlogModel>? blogs,
    int? currentPage,
    int? totalPages,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return BlogListLoaded(
      blogs: blogs ?? this.blogs,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class BlogDetailLoaded extends BlogState {
  final BlogModel blog;

  const BlogDetailLoaded({required this.blog});

  @override
  List<Object?> get props => [blog];
}

class BlogError extends BlogState {
  final String message;

  const BlogError({required this.message});

  @override
  List<Object?> get props => [message];
}

// Bloc
class BlogBloc extends Bloc<BlogEvent, BlogState> {
  final BlogRepository _blogRepository;

  BlogBloc({BlogRepository? blogRepository})
      : _blogRepository = blogRepository ?? BlogRepository(),
        super(const BlogInitial()) {
    on<BlogLoadList>(_onLoadList);
    on<BlogLoadMore>(_onLoadMore);
    on<BlogLoadDetail>(_onLoadDetail);
    on<BlogRefresh>(_onRefresh);
  }

  Future<void> _onLoadList(BlogLoadList event, Emitter<BlogState> emit) async {
    try {
      if (event.refresh || state is BlogInitial || state is BlogError) {
        emit(const BlogLoading());
      }

      final response = await _blogRepository.getBlogs(
        page: event.page,
        pageSize: event.pageSize,
      );

      emit(BlogListLoaded(
        blogs: response.blogs,
        currentPage: response.page,
        totalPages: response.totalPages,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      emit(BlogError(message: e.toString()));
    }
  }

  Future<void> _onLoadMore(BlogLoadMore event, Emitter<BlogState> emit) async {
    if (state is! BlogListLoaded) return;
    final currentState = state as BlogListLoaded;

    if (currentState.isLoadingMore || !currentState.hasMore) return;

    try {
      emit(currentState.copyWith(isLoadingMore: true));

      final response = await _blogRepository.getBlogs(
        page: currentState.currentPage + 1,
        pageSize: 10,
      );

      emit(BlogListLoaded(
        blogs: [...currentState.blogs, ...response.blogs],
        currentPage: response.page,
        totalPages: response.totalPages,
        hasMore: response.hasMore,
        isLoadingMore: false,
      ));
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onLoadDetail(BlogLoadDetail event, Emitter<BlogState> emit) async {
    try {
      emit(const BlogLoading());

      final blog = await _blogRepository.getBlog(event.blogId);
      emit(BlogDetailLoaded(blog: blog));
    } catch (e) {
      emit(BlogError(message: e.toString()));
    }
  }

  Future<void> _onRefresh(BlogRefresh event, Emitter<BlogState> emit) async {
    add(const BlogLoadList(refresh: true));
  }
}
