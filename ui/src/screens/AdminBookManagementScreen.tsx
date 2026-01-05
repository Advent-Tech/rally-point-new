import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  SafeAreaView,
  ScrollView,
  TouchableOpacity,
  Alert,
  Modal,
  TextInput,
  ActivityIndicator,
  FlatList,
} from 'react-native';
import { Ionicons, MaterialIcons } from '@expo/vector-icons';
import { useAuth } from '../contexts/AuthContext';
import { BookService, Book, BookStats } from '../services/BookService';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';

interface AdminBookManagementScreenProps {
  navigation: any;
}

const AdminBookManagementScreen: React.FC<AdminBookManagementScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const [books, setBooks] = useState<Book[]>([]);
  const [stats, setStats] = useState<BookStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [editingBook, setEditingBook] = useState<Book | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedCategory, setSelectedCategory] = useState<string>('all');

  // Form state for adding/editing books
  const [formData, setFormData] = useState({
    title: '',
    author: '',
    isbn: '',
    category: 'bible' as Book['category'],
    description: '',
    language: 'English',
    price: '',
    stockQuantity: '',
    lowStockThreshold: '',
    barcode: '',
  });

  const [formErrors, setFormErrors] = useState<Record<string, string>>({});
  const [submitting, setSubmitting] = useState(false);

  const categories = [
    { value: 'all', label: 'All Categories' },
    { value: 'bible', label: 'Bible' },
    { value: 'tract', label: 'Tract' },
    { value: 'magazine', label: 'Magazine' },
    { value: 'study_guide', label: 'Study Guide' },
    { value: 'book', label: 'Book' },
    { value: 'other', label: 'Other' },
  ];

  useEffect(() => {
    loadBooks();
    loadStats();
  }, []);

  const loadBooks = async () => {
    try {
      setLoading(true);
      const booksData = await BookService.getBooks();
      setBooks(booksData);
    } catch (error) {
      console.error('Error loading books:', error);
      Alert.alert('Error', 'Failed to load books');
    } finally {
      setLoading(false);
    }
  };

  const loadStats = async () => {
    try {
      const statsData = await BookService.getBookStats();
      setStats(statsData);
    } catch (error) {
      console.error('Error loading stats:', error);
    }
  };

  const resetForm = () => {
    setFormData({
      title: '',
      author: '',
      isbn: '',
      category: 'bible',
      description: '',
      language: 'English',
      price: '',
      stockQuantity: '',
      lowStockThreshold: '',
      barcode: '',
    });
    setFormErrors({});
    setEditingBook(null);
  };

  const validateForm = (): boolean => {
    const errors: Record<string, string> = {};

    if (!formData.title.trim()) {
      errors.title = 'Title is required';
    }

    if (!formData.stockQuantity || isNaN(Number(formData.stockQuantity)) || Number(formData.stockQuantity) < 0) {
      errors.stockQuantity = 'Valid stock quantity is required';
    }

    if (!formData.lowStockThreshold || isNaN(Number(formData.lowStockThreshold)) || Number(formData.lowStockThreshold) < 0) {
      errors.lowStockThreshold = 'Valid low stock threshold is required';
    }

    if (formData.price && (isNaN(Number(formData.price)) || Number(formData.price) < 0)) {
      errors.price = 'Price must be a valid number';
    }

    setFormErrors(errors);
    return Object.keys(errors).length === 0;
  };

  const handleSubmit = async () => {
    if (!validateForm()) {
      return;
    }

    setSubmitting(true);
    try {
      const bookData: Omit<Book, 'id' | 'createdAt' | 'updatedAt'> = {
        title: formData.title.trim(),
        author: formData.author.trim() || undefined,
        isbn: formData.isbn.trim() || undefined,
        category: formData.category,
        description: formData.description.trim() || undefined,
        language: formData.language,
        price: formData.price ? Number(formData.price) : undefined,
        stockQuantity: Number(formData.stockQuantity),
        lowStockThreshold: Number(formData.lowStockThreshold),
        barcode: formData.barcode.trim() || undefined,
        isActive: true,
        createdBy: {
          uid: user.uid,
          name: user.displayName || user.email?.split('@')[0] || 'Admin',
          email: user.email || '',
        },
      };

      if (editingBook) {
        await BookService.updateBook(editingBook.id, bookData);
        Alert.alert('Success', 'Book updated successfully');
      } else {
        await BookService.createBook(bookData);
        Alert.alert('Success', 'Book added successfully');
      }

      setShowAddModal(false);
      resetForm();
      loadBooks();
      loadStats();
    } catch (error) {
      console.error('Error saving book:', error);
      Alert.alert('Error', 'Failed to save book');
    } finally {
      setSubmitting(false);
    }
  };

  const handleEditBook = (book: Book) => {
    setEditingBook(book);
    setFormData({
      title: book.title,
      author: book.author || '',
      isbn: book.isbn || '',
      category: book.category,
      description: book.description || '',
      language: book.language,
      price: book.price?.toString() || '',
      stockQuantity: book.stockQuantity.toString(),
      lowStockThreshold: book.lowStockThreshold.toString(),
      barcode: book.barcode || '',
    });
    setShowAddModal(true);
  };

  const handleDeleteBook = (book: Book) => {
    Alert.alert(
      'Delete Book',
      `Are you sure you want to delete "${book.title}"?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            try {
              await BookService.deleteBook(book.id);
              Alert.alert('Success', 'Book deleted successfully');
              loadBooks();
              loadStats();
            } catch (error) {
              console.error('Error deleting book:', error);
              Alert.alert('Error', 'Failed to delete book');
            }
          },
        },
      ]
    );
  };

  const filteredBooks = books.filter(book => {
    const matchesSearch = book.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
                         (book.author && book.author.toLowerCase().includes(searchQuery.toLowerCase()));
    const matchesCategory = selectedCategory === 'all' || book.category === selectedCategory;
    return matchesSearch && matchesCategory;
  });

  const getCategoryColor = (category: string): string => {
    const colors: Record<string, string> = {
      bible: '#7c3aed',
      tract: '#059669',
      magazine: '#dc2626',
      study_guide: '#2563eb',
      book: '#ea580c',
      other: '#6b7280',
    };
    return colors[category] || colors.other;
  };

  const getCategoryIcon = (category: string): string => {
    const icons: Record<string, string> = {
      bible: 'menu-book',
      tract: 'article',
      magazine: 'library-books',
      study_guide: 'school',
      book: 'book',
      other: 'description',
    };
    return icons[category] || icons.other;
  };

  return (
    <SafeAreaView style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Ionicons name="arrow-back" size={24} color={COLORS.text.primary} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>Book Management</Text>
        <TouchableOpacity
          onPress={() => {
            resetForm();
            setShowAddModal(true);
          }}
        >
          <Ionicons name="add" size={24} color={COLORS.primary.main} />
        </TouchableOpacity>
      </View>

      {/* Stats Cards */}
      {stats && (
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.statsContainer}>
          <View style={styles.statCard}>
            <Text style={styles.statNumber}>{stats.totalBooks}</Text>
            <Text style={styles.statLabel}>Total Books</Text>
          </View>
          <View style={styles.statCard}>
            <Text style={styles.statNumber}>{stats.activeBooks}</Text>
            <Text style={styles.statLabel}>Active</Text>
          </View>
          <View style={[styles.statCard, stats.lowStockBooks > 0 && styles.warningCard]}>
            <Text style={[styles.statNumber, stats.lowStockBooks > 0 && styles.warningText]}>
              {stats.lowStockBooks}
            </Text>
            <Text style={[styles.statLabel, stats.lowStockBooks > 0 && styles.warningText]}>
              Low Stock
            </Text>
          </View>
          <View style={styles.statCard}>
            <Text style={styles.statNumber}>${stats.totalValue.toFixed(0)}</Text>
            <Text style={styles.statLabel}>Total Value</Text>
          </View>
        </ScrollView>
      )}

      {/* Search and Filter */}
      <View style={styles.searchContainer}>
        <View style={styles.searchInputContainer}>
          <Ionicons name="search" size={20} color={COLORS.text.secondary} />
          <TextInput
            style={styles.searchInput}
            placeholder="Search books..."
            value={searchQuery}
            onChangeText={setSearchQuery}
            placeholderTextColor={COLORS.text.secondary}
          />
        </View>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.categoryFilter}>
          {categories.map((category) => (
            <TouchableOpacity
              key={category.value}
              style={[
                styles.categoryChip,
                selectedCategory === category.value && styles.selectedCategoryChip
              ]}
              onPress={() => setSelectedCategory(category.value)}
            >
              <Text style={[
                styles.categoryChipText,
                selectedCategory === category.value && styles.selectedCategoryChipText
              ]}>
                {category.label}
              </Text>
            </TouchableOpacity>
          ))}
        </ScrollView>
      </View>

      {/* Books List */}
      {loading ? (
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color={COLORS.primary.main} />
          <Text style={styles.loadingText}>Loading books...</Text>
        </View>
      ) : (
        <FlatList
          data={filteredBooks}
          keyExtractor={(item) => item.id}
          renderItem={({ item }) => (
            <View style={styles.bookItem}>
              <View style={styles.bookInfo}>
                <View style={[styles.bookIcon, { backgroundColor: getCategoryColor(item.category) }]}>
                  <MaterialIcons name={getCategoryIcon(item.category)} size={24} color="#FFFFFF" />
                </View>
                <View style={styles.bookDetails}>
                  <Text style={styles.bookTitle}>{item.title}</Text>
                  {item.author && <Text style={styles.bookAuthor}>by {item.author}</Text>}
                  <Text style={styles.bookCategory}>{item.category.replace('_', ' ').toUpperCase()}</Text>
                  <View style={styles.stockInfo}>
                    <Text style={[
                      styles.stockText,
                      item.stockQuantity <= item.lowStockThreshold && styles.lowStockText
                    ]}>
                      Stock: {item.stockQuantity}
                    </Text>
                    {item.price && <Text style={styles.priceText}>${item.price}</Text>}
                  </View>
                </View>
              </View>
              <View style={styles.bookActions}>
                <TouchableOpacity
                  style={styles.actionButton}
                  onPress={() => handleEditBook(item)}
                >
                  <MaterialIcons name="edit" size={20} color={COLORS.primary.main} />
                </TouchableOpacity>
                <TouchableOpacity
                  style={styles.actionButton}
                  onPress={() => handleDeleteBook(item)}
                >
                  <MaterialIcons name="delete" size={20} color={COLORS.error.main} />
                </TouchableOpacity>
              </View>
            </View>
          )}
          contentContainerStyle={styles.booksList}
          showsVerticalScrollIndicator={false}
        />
      )}

      {/* Add/Edit Book Modal */}
      <Modal
        visible={showAddModal}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => {
          setShowAddModal(false);
          resetForm();
        }}
      >
        <SafeAreaView style={styles.modalContainer}>
          <View style={styles.modalHeader}>
            <TouchableOpacity
              onPress={() => {
                setShowAddModal(false);
                resetForm();
              }}
            >
              <Text style={styles.cancelButton}>Cancel</Text>
            </TouchableOpacity>
            <Text style={styles.modalTitle}>
              {editingBook ? 'Edit Book' : 'Add New Book'}
            </Text>
            <TouchableOpacity
              onPress={handleSubmit}
              disabled={submitting}
            >
              <Text style={[styles.saveButton, submitting && styles.disabledButton]}>
                {submitting ? 'Saving...' : 'Save'}
              </Text>
            </TouchableOpacity>
          </View>

          <ScrollView style={styles.modalContent} showsVerticalScrollIndicator={false}>
            {/* Title */}
            <View style={styles.formGroup}>
              <Text style={styles.formLabel}>Title *</Text>
              <TextInput
                style={[styles.formInput, formErrors.title && styles.inputError]}
                value={formData.title}
                onChangeText={(text) => setFormData(prev => ({ ...prev, title: text }))}
                placeholder="Enter book title"
                placeholderTextColor={COLORS.text.secondary}
              />
              {formErrors.title && <Text style={styles.errorText}>{formErrors.title}</Text>}
            </View>

            {/* Author */}
            <View style={styles.formGroup}>
              <Text style={styles.formLabel}>Author</Text>
              <TextInput
                style={styles.formInput}
                value={formData.author}
                onChangeText={(text) => setFormData(prev => ({ ...prev, author: text }))}
                placeholder="Enter author name"
                placeholderTextColor={COLORS.text.secondary}
              />
            </View>

            {/* Category */}
            <View style={styles.formGroup}>
              <Text style={styles.formLabel}>Category *</Text>
              <ScrollView horizontal showsHorizontalScrollIndicator={false}>
                {categories.slice(1).map((category) => (
                  <TouchableOpacity
                    key={category.value}
                    style={[
                      styles.categoryOption,
                      formData.category === category.value && styles.selectedCategoryOption
                    ]}
                    onPress={() => setFormData(prev => ({ ...prev, category: category.value as Book['category'] }))}
                  >
                    <Text style={[
                      styles.categoryOptionText,
                      formData.category === category.value && styles.selectedCategoryOptionText
                    ]}>
                      {category.label}
                    </Text>
                  </TouchableOpacity>
                ))}
              </ScrollView>
            </View>

            {/* Stock Quantity */}
            <View style={styles.formGroup}>
              <Text style={styles.formLabel}>Stock Quantity *</Text>
              <TextInput
                style={[styles.formInput, formErrors.stockQuantity && styles.inputError]}
                value={formData.stockQuantity}
                onChangeText={(text) => setFormData(prev => ({ ...prev, stockQuantity: text }))}
                placeholder="Enter stock quantity"
                placeholderTextColor={COLORS.text.secondary}
                keyboardType="numeric"
              />
              {formErrors.stockQuantity && <Text style={styles.errorText}>{formErrors.stockQuantity}</Text>}
            </View>

            {/* Low Stock Threshold */}
            <View style={styles.formGroup}>
              <Text style={styles.formLabel}>Low Stock Threshold *</Text>
              <TextInput
                style={[styles.formInput, formErrors.lowStockThreshold && styles.inputError]}
                value={formData.lowStockThreshold}
                onChangeText={(text) => setFormData(prev => ({ ...prev, lowStockThreshold: text }))}
                placeholder="Enter low stock threshold"
                placeholderTextColor={COLORS.text.secondary}
                keyboardType="numeric"
              />
              {formErrors.lowStockThreshold && <Text style={styles.errorText}>{formErrors.lowStockThreshold}</Text>}
            </View>

            {/* Price */}
            <View style={styles.formGroup}>
              <Text style={styles.formLabel}>Price</Text>
              <TextInput
                style={[styles.formInput, formErrors.price && styles.inputError]}
                value={formData.price}
                onChangeText={(text) => setFormData(prev => ({ ...prev, price: text }))}
                placeholder="Enter price (optional)"
                placeholderTextColor={COLORS.text.secondary}
                keyboardType="decimal-pad"
              />
              {formErrors.price && <Text style={styles.errorText}>{formErrors.price}</Text>}
            </View>

            {/* Language */}
            <View style={styles.formGroup}>
              <Text style={styles.formLabel}>Language</Text>
              <TextInput
                style={styles.formInput}
                value={formData.language}
                onChangeText={(text) => setFormData(prev => ({ ...prev, language: text }))}
                placeholder="Enter language"
                placeholderTextColor={COLORS.text.secondary}
              />
            </View>

            {/* ISBN */}
            <View style={styles.formGroup}>
              <Text style={styles.formLabel}>ISBN</Text>
              <TextInput
                style={styles.formInput}
                value={formData.isbn}
                onChangeText={(text) => setFormData(prev => ({ ...prev, isbn: text }))}
                placeholder="Enter ISBN"
                placeholderTextColor={COLORS.text.secondary}
              />
            </View>

            {/* Barcode */}
            <View style={styles.formGroup}>
              <Text style={styles.formLabel}>Barcode</Text>
              <TextInput
                style={styles.formInput}
                value={formData.barcode}
                onChangeText={(text) => setFormData(prev => ({ ...prev, barcode: text }))}
                placeholder="Enter barcode"
                placeholderTextColor={COLORS.text.secondary}
              />
            </View>

            {/* Description */}
            <View style={styles.formGroup}>
              <Text style={styles.formLabel}>Description</Text>
              <TextInput
                style={[styles.formInput, styles.textArea]}
                value={formData.description}
                onChangeText={(text) => setFormData(prev => ({ ...prev, description: text }))}
                placeholder="Enter book description"
                placeholderTextColor={COLORS.text.secondary}
                multiline
                numberOfLines={4}
                textAlignVertical="top"
              />
            </View>
          </ScrollView>
        </SafeAreaView>
      </Modal>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
    backgroundColor: '#FFFFFF',
  },
  headerTitle: {
    ...TYPOGRAPHY.h2,
    fontWeight: '700',
    color: COLORS.text.primary,
  },
  statsContainer: {
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
  },
  statCard: {
    backgroundColor: '#FFFFFF',
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    marginRight: SPACING.md,
    minWidth: 100,
    alignItems: 'center',
    ...SHADOWS.small,
  },
  warningCard: {
    backgroundColor: COLORS.warning.light,
  },
  statNumber: {
    ...TYPOGRAPHY.h2,
    fontWeight: '700',
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  warningText: {
    color: COLORS.warning.main,
  },
  statLabel: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    textAlign: 'center',
  },
  searchContainer: {
    paddingHorizontal: SPACING.lg,
    paddingBottom: SPACING.md,
  },
  searchInputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    borderRadius: RADIUS.md,
    paddingHorizontal: SPACING.md,
    marginBottom: SPACING.md,
    ...SHADOWS.small,
  },
  searchInput: {
    flex: 1,
    ...TYPOGRAPHY.body,
    color: COLORS.text.primary,
    paddingVertical: SPACING.md,
    marginLeft: SPACING.sm,
  },
  categoryFilter: {
    flexDirection: 'row',
  },
  categoryChip: {
    backgroundColor: '#FFFFFF',
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    borderRadius: RADIUS.full,
    marginRight: SPACING.sm,
    borderWidth: 1,
    borderColor: COLORS.border.light,
  },
  selectedCategoryChip: {
    backgroundColor: COLORS.primary.main,
    borderColor: COLORS.primary.main,
  },
  categoryChipText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    fontWeight: '500',
  },
  selectedCategoryChipText: {
    color: '#FFFFFF',
  },
  loadingContainer: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  loadingText: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.secondary,
    marginTop: SPACING.md,
  },
  booksList: {
    paddingHorizontal: SPACING.lg,
    paddingBottom: SPACING.xl,
  },
  bookItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#FFFFFF',
    padding: SPACING.md,
    marginBottom: SPACING.sm,
    borderRadius: RADIUS.md,
    ...SHADOWS.small,
  },
  bookInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  bookIcon: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: SPACING.md,
  },
  bookDetails: {
    flex: 1,
  },
  bookTitle: {
    ...TYPOGRAPHY.body,
    fontWeight: '600',
    color: COLORS.text.primary,
    marginBottom: 2,
  },
  bookAuthor: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    marginBottom: 2,
  },
  bookCategory: {
    ...TYPOGRAPHY.caption,
    color: COLORS.primary.main,
    fontWeight: '500',
    marginBottom: 4,
  },
  stockInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: SPACING.sm,
  },
  stockText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
  },
  lowStockText: {
    color: COLORS.warning.main,
    fontWeight: '600',
  },
  priceText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.success.main,
    fontWeight: '500',
  },
  bookActions: {
    flexDirection: 'row',
    gap: SPACING.sm,
  },
  actionButton: {
    padding: SPACING.sm,
    borderRadius: RADIUS.sm,
    backgroundColor: COLORS.background.secondary,
  },
  modalContainer: {
    flex: 1,
    backgroundColor: COLORS.background.primary,
  },
  modalHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.md,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
    backgroundColor: '#FFFFFF',
  },
  modalTitle: {
    ...TYPOGRAPHY.h3,
    fontWeight: '600',
    color: COLORS.text.primary,
  },
  cancelButton: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.secondary,
  },
  saveButton: {
    ...TYPOGRAPHY.body,
    color: COLORS.primary.main,
    fontWeight: '600',
  },
  disabledButton: {
    color: COLORS.text.secondary,
  },
  modalContent: {
    flex: 1,
    paddingHorizontal: SPACING.lg,
  },
  formGroup: {
    marginBottom: SPACING.lg,
  },
  formLabel: {
    ...TYPOGRAPHY.body,
    fontWeight: '500',
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  formInput: {
    borderWidth: 1,
    borderColor: COLORS.border.light,
    borderRadius: RADIUS.md,
    padding: SPACING.md,
    ...TYPOGRAPHY.body,
    color: COLORS.text.primary,
    backgroundColor: '#FFFFFF',
  },
  textArea: {
    minHeight: 100,
    textAlignVertical: 'top',
  },
  inputError: {
    borderColor: COLORS.error.main,
  },
  errorText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.error.main,
    marginTop: SPACING.xs,
  },
  categoryOption: {
    backgroundColor: '#FFFFFF',
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    borderRadius: RADIUS.md,
    marginRight: SPACING.sm,
    borderWidth: 1,
    borderColor: COLORS.border.light,
  },
  selectedCategoryOption: {
    backgroundColor: COLORS.primary.main,
    borderColor: COLORS.primary.main,
  },
  categoryOptionText: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.secondary,
    fontWeight: '500',
  },
  selectedCategoryOptionText: {
    color: '#FFFFFF',
  },
});

export default AdminBookManagementScreen;
