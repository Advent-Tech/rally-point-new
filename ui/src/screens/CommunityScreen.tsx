import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  StyleSheet,
  StatusBar,
  Dimensions,
  Platform,
  Animated,
  Alert,
  TextInput,
  Modal,
  RefreshControl,
  KeyboardAvoidingView,
  Image,
  Clipboard,
  Share,
  FlatList,
  ActivityIndicator,
} from 'react-native';
import { useAuth } from '../contexts/AuthContext';
import Icon from '../components/Icon';
import Header from '../components/Header';
import { COLORS, TYPOGRAPHY, SPACING, RADIUS, SHADOWS } from '../constants/Colors';
import { MaterialIcons, FontAwesome, Feather } from '@expo/vector-icons';
import CommunityService from '../services/CommunityService';

const { width } = Dimensions.get('window');

interface CommunityScreenProps {
  navigation: any;
}

interface NewsItem {
  id: string;
  title: string;
  content: string;
  author: string;
  timestamp: Date;
  likes: number;
  comments: number;
  image?: string;
}

interface Message {
  id: string;
  sender: string;
  content: string;
  timestamp: Date;
  isRead: boolean;
}

interface MissionTrip {
  id: string;
  title: string;
  location: string;
  date: string;
  duration: string;
  spotsAvailable: number;
  totalSpots: number;
  description: string;
}

interface Volunteer {
  id: string;
  name: string;
  skills: string[];
  availability: string;
  contact: string;
  rating: number;
}

const CommunityScreen: React.FC<CommunityScreenProps> = ({ navigation }) => {
  const { user } = useAuth();
  const [activeTab, setActiveTab] = useState('news');
  const [refreshing, setRefreshing] = useState(false);
  const [loading, setLoading] = useState(false);
  const [createPostModalVisible, setCreatePostModalVisible] = useState(false);
  const [postContent, setPostContent] = useState('');
  const [postImage, setPostImage] = useState<string | null>(null);
  const [isBold, setIsBold] = useState(false);
  const [likedPosts, setLikedPosts] = useState<Set<string>>(new Set());
  const [signedUpTrips, setSignedUpTrips] = useState<Set<string>>(new Set());

  // Empty state data - will be populated from Firebase
  const [newsItems, setNewsItems] = useState<NewsItem[]>([]);
  const [missionTrips, setMissionTrips] = useState<MissionTrip[]>([]);
  const [volunteers, setVolunteers] = useState<Volunteer[]>([]);

  // Comment modal state
  const [commentModalVisible, setCommentModalVisible] = useState(false);
  const [selectedPostId, setSelectedPostId] = useState<string | null>(null);
  const [comments, setComments] = useState<any[]>([]);
  const [commentText, setCommentText] = useState('');
  const [loadingComments, setLoadingComments] = useState(false);
  const [postingComment, setPostingComment] = useState(false);

  // Share modal state
  const [shareModalVisible, setShareModalVisible] = useState(false);
  const [selectedSharePostId, setSelectedSharePostId] = useState<string | null>(null);

  // Initial load only
  useEffect(() => {
    loadData();
  }, []);

  // Reload data when tab changes
  useEffect(() => {
    if (activeTab) {
      loadData();
    }
  }, [activeTab]);

  const loadData = async () => {
    if (!user) return;

    setLoading(true);
    try {
      // Load data from Firebase based on active tab
      if (activeTab === 'news') {
        const news = await CommunityService.getNewsItems(20);
        setNewsItems(news);

        // Load user's liked posts
        const userLikes = new Set<string>();
        news.forEach(item => {
          // Check if user has liked this post (you'll need to implement this in CommunityService)
          // For now, we'll use local state
        });
        setLikedPosts(userLikes);
      } else if (activeTab === 'trips') {
        const trips = await CommunityService.getMissionTrips();
        setMissionTrips(trips);

        // Load user's signed up trips
        const userTrips = new Set<string>();
        // You'll need to implement getUserSignedUpTrips in CommunityService
        setSignedUpTrips(userTrips);
      } else if (activeTab === 'volunteers') {
        const vols = await CommunityService.getVolunteers();
        setVolunteers(vols);
      }
    } catch (error) {
      console.error('Error loading community data:', error);
      Alert.alert('Error', 'Failed to load data. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const onRefresh = React.useCallback(async () => {
    setRefreshing(true);
    try {
      await loadData();
    } catch (error) {
      console.error('Error refreshing data:', error);
    } finally {
      setRefreshing(false);
    }
  }, [activeTab, user]);

  const handleTabPress = (tab: string) => {
    setActiveTab(tab);
  };

  const handleCreatePost = async () => {
    if (!postContent.trim() || !user) {
      Alert.alert('Error', 'Please enter some content for your post');
      return;
    }

    try {
      const postData: any = {
        title: postContent.substring(0, 50) + (postContent.length > 50 ? '...' : ''),
        content: postContent,
        author: user.displayName || user.email || 'Anonymous',
        authorId: user.uid,
      };

      // Only add image field if it exists
      if (postImage) {
        postData.image = postImage;
      }

      await CommunityService.createNewsItem(postData);

      // Reset form
      setPostContent('');
      setPostImage(null);
      setIsBold(false);
      setCreatePostModalVisible(false);

      // Reload news items
      const news = await CommunityService.getNewsItems(20);
      setNewsItems(news);

      Alert.alert('Success', 'Your post has been created!');
    } catch (error) {
      console.error('Error creating post:', error);
      Alert.alert('Error', 'Failed to create post. Please try again.');
    }
  };

  const handleLikePost = async (postId: string) => {
    if (!user) return;

    try {
      const isLiked = likedPosts.has(postId);

      if (isLiked) {
        // Unlike
        await CommunityService.unlikeNewsItem(postId, user.uid);
        setLikedPosts(prev => {
          const newSet = new Set(prev);
          newSet.delete(postId);
          return newSet;
        });
      } else {
        // Like
        await CommunityService.likeNewsItem(postId, user.uid);
        setLikedPosts(prev => new Set(prev).add(postId));
      }

      // Update local state
      setNewsItems(prev => prev.map(item =>
        item.id === postId
          ? { ...item, likes: isLiked ? item.likes - 1 : item.likes + 1 }
          : item
      ));
    } catch (error) {
      console.error('Error liking post:', error);
      Alert.alert('Error', 'Failed to like post. Please try again.');
    }
  };

  const handleCommentPress = async (postId: string) => {
    setSelectedPostId(postId);
    setCommentModalVisible(true);
    setLoadingComments(true);

    try {
      const fetchedComments = await CommunityService.getComments(postId);
      setComments(fetchedComments);
    } catch (error) {
      console.error('Error loading comments:', error);
      Alert.alert('Error', 'Failed to load comments. Please try again.');
    } finally {
      setLoadingComments(false);
    }
  };

  const handlePostComment = async () => {
    if (!user || !selectedPostId || !commentText.trim()) return;

    setPostingComment(true);
    try {
      await CommunityService.addComment(
        selectedPostId,
        user.uid,
        user.displayName || user.email || 'Anonymous',
        commentText.trim()
      );

      // Reload comments
      const fetchedComments = await CommunityService.getComments(selectedPostId);
      setComments(fetchedComments);

      // Update comment count in local state
      setNewsItems(prev => prev.map(item =>
        item.id === selectedPostId
          ? { ...item, comments: item.comments + 1 }
          : item
      ));

      setCommentText('');
      Alert.alert('Success', 'Comment posted successfully!');
    } catch (error) {
      console.error('Error posting comment:', error);
      Alert.alert('Error', 'Failed to post comment. Please try again.');
    } finally {
      setPostingComment(false);
    }
  };

  const handleCloseCommentModal = () => {
    setCommentModalVisible(false);
    setSelectedPostId(null);
    setComments([]);
    setCommentText('');
  };

  const handleSharePress = (postId: string) => {
    setSelectedSharePostId(postId);
    setShareModalVisible(true);
  };

  const handleCopyLink = async () => {
    if (!selectedSharePostId) return;

    try {
      const link = `rallypoint://news/${selectedSharePostId}`;
      if (Platform.OS === 'web') {
        await navigator.clipboard.writeText(link);
      } else {
        Clipboard.setString(link);
      }

      await CommunityService.shareNewsItem(selectedSharePostId, user?.uid || '', 'copy_link');

      // Update share count
      setNewsItems(prev => prev.map(item =>
        item.id === selectedSharePostId
          ? { ...item, shares: (item.shares || 0) + 1 }
          : item
      ));

      setShareModalVisible(false);
      Alert.alert('Success', 'Link copied to clipboard!');
    } catch (error) {
      console.error('Error copying link:', error);
      Alert.alert('Error', 'Failed to copy link. Please try again.');
    }
  };

  const handleShareExternal = async () => {
    if (!selectedSharePostId) return;

    try {
      const post = newsItems.find(item => item.id === selectedSharePostId);
      if (!post) return;

      const message = `Check out this post: ${post.title}\n\n${post.content}`;

      if (Platform.OS === 'web') {
        // Web fallback - copy to clipboard
        await navigator.clipboard.writeText(message);
        Alert.alert('Success', 'Post content copied to clipboard!');
      } else {
        // Mobile - use native share
        await Share.share({
          message,
          title: post.title,
        });
      }

      await CommunityService.shareNewsItem(selectedSharePostId, user?.uid || '', 'external');

      // Update share count
      setNewsItems(prev => prev.map(item =>
        item.id === selectedSharePostId
          ? { ...item, shares: (item.shares || 0) + 1 }
          : item
      ));

      setShareModalVisible(false);
    } catch (error: any) {
      if (error.message !== 'User did not share') {
        console.error('Error sharing:', error);
        Alert.alert('Error', 'Failed to share. Please try again.');
      }
    }
  };

  const handleCloseShareModal = () => {
    setShareModalVisible(false);
    setSelectedSharePostId(null);
  };

  const handleSignUpForTrip = async (tripId: string) => {
    if (!user) return;

    try {
      const isSignedUp = signedUpTrips.has(tripId);

      if (isSignedUp) {
        Alert.alert('Already Signed Up', 'You are already signed up for this trip.');
        return;
      }

      await CommunityService.signUpForTrip(tripId, user.uid);
      setSignedUpTrips(prev => new Set(prev).add(tripId));

      // Update local state
      setMissionTrips(prev => prev.map(trip =>
        trip.id === tripId
          ? { ...trip, spotsAvailable: trip.spotsAvailable - 1 }
          : trip
      ));

      Alert.alert('Success', 'You have successfully signed up for this trip!');
    } catch (error) {
      console.error('Error signing up for trip:', error);
      Alert.alert('Error', 'Failed to sign up. Please try again.');
    }
  };

  const handleContactVolunteer = (volunteer: Volunteer) => {
    Alert.alert(
      'Contact Volunteer',
      `Contact ${volunteer.name} at ${volunteer.contact}`,
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Email', onPress: () => console.log('Email:', volunteer.contact) },
        { text: 'Call', onPress: () => console.log('Call:', volunteer.contact) },
      ]
    );
  };

  const formatTimeAgo = (date: Date) => {
    const now = new Date();
    const diffInMinutes = Math.floor((now.getTime() - date.getTime()) / (1000 * 60));
    
    if (diffInMinutes < 60) {
      return `${diffInMinutes}m ago`;
    } else if (diffInMinutes < 1440) {
      return `${Math.floor(diffInMinutes / 60)}h ago`;
    } else {
      return `${Math.floor(diffInMinutes / 1440)}d ago`;
    }
  };

  const renderTabButton = (tabKey: string, label: string, iconName: string) => {
    const isActive = activeTab === tabKey;
    return (
      <TouchableOpacity
        key={tabKey}
        style={[styles.tabButton, isActive && styles.activeTabButton]}
        onPress={() => handleTabPress(tabKey)}
      >
        <Icon
          name={iconName}
          size={20}
          color={isActive ? COLORS.white : COLORS.text.secondary}
        />
        <Text style={[styles.tabButtonText, isActive && styles.activeTabButtonText]}>
          {label}
        </Text>
      </TouchableOpacity>
    );
  };

  const renderEmptyState = (message: string, iconName: string) => (
    <View style={styles.emptyState}>
      <Icon name={iconName} size={64} color={COLORS.text.disabled} />
      <Text style={styles.emptyStateText}>{message}</Text>
    </View>
  );

  if (!user) {
    return (
      <View style={[styles.container, { justifyContent: 'center', alignItems: 'center' }]}>
        <Text style={{ fontSize: 18, color: COLORS.text.primary }}>Loading...</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor="#F3F4F9" />

      {/* Header */}
      <Header
        title="Community"
        showMenu={true}
        onMenuPress={() => navigation.openDrawer?.() || navigation.toggleDrawer?.()}
        showNotifications={true}
      />

      {/* Tab Navigation */}
      <View style={styles.tabContainer}>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.tabScrollView}>
          {renderTabButton('news', 'News Feed', 'book-open')}
          {renderTabButton('trips', 'Mission Trips', 'map-pin')}
          {renderTabButton('volunteers', 'Volunteers', 'users')}
          {renderTabButton('checkin', 'Child Check-in', 'user-check')}
        </ScrollView>
      </View>

      {/* Content Area */}
      <ScrollView
        style={styles.content}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} />}
      >
        <View>
          {activeTab === 'news' && (
            <View style={styles.tabContent}>
              <View style={styles.sectionHeader}>
                <Text style={styles.sectionTitle}>Community News</Text>
                <TouchableOpacity onPress={() => setCreatePostModalVisible(true)}>
                  <Icon name="plus-circle" size={24} color={COLORS.primary} />
                </TouchableOpacity>
              </View>

              {newsItems.length === 0 ? (
                renderEmptyState('No news posts yet. Be the first to share!', 'book-open')
              ) : (
                newsItems.map((item) => (
                <View key={item.id} style={styles.newsCard}>
                  <View style={styles.newsHeader}>
                    <View style={styles.authorInfo}>
                      <View style={styles.authorAvatar}>
                        <Text style={styles.authorInitial}>{item.author.charAt(0)}</Text>
                      </View>
                      <View>
                        <Text style={styles.authorName}>{item.author}</Text>
                        <Text style={styles.timestamp}>{formatTimeAgo(item.timestamp)}</Text>
                      </View>
                    </View>
                  </View>

                  <Text style={styles.newsTitle}>{item.title}</Text>
                  <Text style={styles.newsContent}>{item.content}</Text>

                  {item.image && (
                    <Image source={{ uri: item.image }} style={styles.newsImage} />
                  )}

                  <View style={styles.newsActions}>
                    <TouchableOpacity
                      style={styles.actionButton}
                      onPress={() => handleLikePost(item.id)}
                    >
                      <MaterialIcons
                        name={likedPosts.has(item.id) ? "favorite" : "favorite-border"}
                        size={18}
                        color={likedPosts.has(item.id) ? '#EA4335' : COLORS.text.secondary}
                      />
                      <Text style={[
                        styles.actionText,
                        likedPosts.has(item.id) && { color: '#EA4335' }
                      ]}>
                        {item.likes}
                      </Text>
                    </TouchableOpacity>
                    <TouchableOpacity
                      style={styles.actionButton}
                      onPress={() => handleCommentPress(item.id)}
                    >
                      <Icon name="message-circle" size={16} color={COLORS.text.secondary} />
                      <Text style={styles.actionText}>{item.comments}</Text>
                    </TouchableOpacity>
                    <TouchableOpacity
                      style={styles.actionButton}
                      onPress={() => handleSharePress(item.id)}
                    >
                      <Icon name="share-2" size={16} color={COLORS.text.secondary} />
                      <Text style={styles.actionText}>{item.shares || 0}</Text>
                    </TouchableOpacity>
                  </View>
                </View>
              ))
              )}
            </View>
          )}

          {activeTab === 'trips' && (
            <View style={styles.tabContent}>
              <View style={styles.sectionHeader}>
                <Text style={styles.sectionTitle}>Mission Trips</Text>
              </View>

              {missionTrips.length === 0 ? (
                renderEmptyState('No mission trips available. Check back later!', 'map-pin')
              ) : (
                missionTrips.map((trip) => (
                <View key={trip.id} style={styles.tripCard}>
                  <View style={styles.tripHeader}>
                    <Text style={styles.tripTitle}>{trip.title}</Text>
                    <View style={styles.spotsIndicator}>
                      <Text style={styles.spotsText}>{trip.spotsAvailable}/{trip.totalSpots}</Text>
                    </View>
                  </View>

                  <View style={styles.tripDetails}>
                    <View style={styles.tripDetailRow}>
                      <Icon name="location-pin" size={16} color={COLORS.text.secondary} />
                      <Text style={styles.tripDetailText}>{trip.location}</Text>
                    </View>
                    <View style={styles.tripDetailRow}>
                      <Icon name="calendar" size={16} color={COLORS.text.secondary} />
                      <Text style={styles.tripDetailText}>{trip.date} • {trip.duration}</Text>
                    </View>
                  </View>

                  <Text style={styles.tripDescription}>{trip.description}</Text>

                  <TouchableOpacity
                    style={[
                      styles.signupButton,
                      (trip.spotsAvailable === 0 || signedUpTrips.has(trip.id)) && styles.disabledButton,
                      signedUpTrips.has(trip.id) && styles.signedUpButton
                    ]}
                    disabled={trip.spotsAvailable === 0 || signedUpTrips.has(trip.id)}
                    onPress={() => handleSignUpForTrip(trip.id)}
                  >
                    <Text style={[
                      styles.signupButtonText,
                      (trip.spotsAvailable === 0 || signedUpTrips.has(trip.id)) && styles.disabledButtonText
                    ]}>
                      {signedUpTrips.has(trip.id)
                        ? 'Signed Up ✓'
                        : trip.spotsAvailable === 0
                          ? 'Full'
                          : 'Sign Up'}
                    </Text>
                  </TouchableOpacity>
                </View>
              ))
              )}
            </View>
          )}

          {activeTab === 'volunteers' && (
            <View style={styles.tabContent}>
              <View style={styles.sectionHeader}>
                <Text style={styles.sectionTitle}>Volunteer Skills</Text>
              </View>

              {volunteers.length === 0 ? (
                renderEmptyState('No volunteers registered yet.', 'users')
              ) : (
                volunteers.map((volunteer) => (
                <View key={volunteer.id} style={styles.volunteerCard}>
                  <View style={styles.volunteerHeader}>
                    <View style={styles.volunteerInfo}>
                      <View style={styles.volunteerAvatar}>
                        <Text style={styles.volunteerInitial}>{volunteer.name.charAt(0)}</Text>
                      </View>
                      <View>
                        <Text style={styles.volunteerName}>{volunteer.name}</Text>
                        <View style={styles.ratingContainer}>
                          {[1, 2, 3, 4, 5].map((star) => (
                            <Icon
                              key={star}
                              name="star"
                              size={12}
                              color={star <= volunteer.rating ? COLORS.secondary : COLORS.border.default}
                            />
                          ))}
                          <Text style={styles.ratingText}>({volunteer.rating})</Text>
                        </View>
                      </View>
                    </View>
                    <TouchableOpacity
                      style={styles.contactButton}
                      onPress={() => handleContactVolunteer(volunteer)}
                    >
                      <Icon name="message-circle" size={16} color={COLORS.primary} />
                    </TouchableOpacity>
                  </View>

                  <View style={styles.skillsContainer}>
                    {volunteer.skills.map((skill, index) => (
                      <View key={index} style={styles.skillTag}>
                        <Text style={styles.skillText}>{skill}</Text>
                      </View>
                    ))}
                  </View>

                  <View style={styles.availabilityContainer}>
                    <Icon name="clock" size={14} color={COLORS.text.secondary} />
                    <Text style={styles.availabilityText}>Available: {volunteer.availability}</Text>
                  </View>
                </View>
              ))
              )}
            </View>
          )}

          {activeTab === 'checkin' && (
            <View style={styles.tabContent}>
              <View style={styles.sectionHeader}>
                <Text style={styles.sectionTitle}>Child Check-in</Text>
              </View>

              <View style={styles.checkinCard}>
                <View style={styles.checkinHeader}>
                  <Icon name="user-check" size={48} color={COLORS.primary} />
                  <Text style={styles.checkinTitle}>QR Code Check-in</Text>
                </View>

                <Text style={styles.checkinDescription}>
                  Scan QR codes to quickly check children in and out of ministry activities and events.
                </Text>

                <View style={styles.checkinActions}>
                  <TouchableOpacity
                    style={styles.checkinButton}
                    onPress={() => Alert.alert(
                      'QR Scanner',
                      'QR code scanner will be implemented using expo-barcode-scanner. This will allow you to scan QR codes to check children in and out.',
                      [{ text: 'OK' }]
                    )}
                  >
                    <Icon name="camera" size={20} color={COLORS.white} />
                    <Text style={styles.checkinButtonText}>Scan QR Code</Text>
                  </TouchableOpacity>

                  <TouchableOpacity
                    style={[styles.checkinButton, styles.secondaryButton]}
                    onPress={() => Alert.alert(
                      'Check-ins',
                      'View all active check-ins and check-in history.',
                      [{ text: 'OK' }]
                    )}
                  >
                    <Icon name="list" size={20} color={COLORS.primary} />
                    <Text style={[styles.checkinButtonText, styles.secondaryButtonText]}>View Check-ins</Text>
                  </TouchableOpacity>
                </View>
              </View>

              <View style={styles.recentCheckins}>
                <Text style={styles.recentTitle}>Recent Check-ins</Text>
                {renderEmptyState('No recent check-ins.', 'user-check')}
              </View>
            </View>
          )}
        </View>
      </ScrollView>

      {/* Create Post Modal */}
      <Modal
        visible={createPostModalVisible}
        animationType="slide"
        transparent={true}
        onRequestClose={() => setCreatePostModalVisible(false)}
      >
        <KeyboardAvoidingView
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          style={styles.modalContainer}
        >
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Create Post</Text>
              <TouchableOpacity onPress={() => setCreatePostModalVisible(false)}>
                <Icon name="x" size={24} color={COLORS.text.primary} />
              </TouchableOpacity>
            </View>

            <ScrollView style={styles.modalBody}>
              <View style={styles.formattingToolbar}>
                <TouchableOpacity
                  style={[styles.formatButton, isBold && styles.formatButtonActive]}
                  onPress={() => setIsBold(!isBold)}
                >
                  <Feather name="bold" size={20} color={isBold ? COLORS.white : COLORS.text.primary} />
                </TouchableOpacity>
              </View>

              <TextInput
                style={[
                  styles.postInput,
                  isBold && { fontWeight: 'bold' }
                ]}
                placeholder="What's on your mind?"
                placeholderTextColor={COLORS.text.disabled}
                multiline
                numberOfLines={6}
                value={postContent}
                onChangeText={setPostContent}
                textAlignVertical="top"
              />

              {postImage && (
                <View style={styles.imagePreview}>
                  <Image source={{ uri: postImage }} style={styles.previewImage} />
                  <TouchableOpacity
                    style={styles.removeImageButton}
                    onPress={() => setPostImage(null)}
                  >
                    <Icon name="x-circle" size={24} color={COLORS.error} />
                  </TouchableOpacity>
                </View>
              )}

              <TouchableOpacity
                style={styles.imageUploadButton}
                onPress={() => Alert.alert('Image Upload', 'Image upload functionality will be implemented')}
              >
                <Icon name="image" size={20} color={COLORS.primary} />
                <Text style={styles.imageUploadText}>Add Image</Text>
              </TouchableOpacity>
            </ScrollView>

            <View style={styles.modalFooter}>
              <TouchableOpacity
                style={styles.cancelButton}
                onPress={() => setCreatePostModalVisible(false)}
              >
                <Text style={styles.cancelButtonText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={styles.submitButton}
                onPress={handleCreatePost}
              >
                <Text style={styles.submitButtonText}>Post</Text>
              </TouchableOpacity>
            </View>
          </View>
        </KeyboardAvoidingView>
      </Modal>

      {/* Comment Modal */}
      <Modal
        visible={commentModalVisible}
        transparent
        animationType="slide"
        onRequestClose={handleCloseCommentModal}
      >
        <KeyboardAvoidingView
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          style={styles.modalOverlay}
        >
          <View style={styles.commentModalContainer}>
            {/* Header */}
            <View style={styles.commentModalHeader}>
              <Text style={styles.commentModalTitle}>Comments</Text>
              <TouchableOpacity onPress={handleCloseCommentModal}>
                <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
              </TouchableOpacity>
            </View>

            {/* Comments List */}
            <ScrollView style={styles.commentsList}>
              {loadingComments ? (
                <View style={styles.loadingContainer}>
                  <ActivityIndicator size="large" color={COLORS.primary} />
                  <Text style={styles.loadingText}>Loading comments...</Text>
                </View>
              ) : comments.length === 0 ? (
                <View style={styles.emptyCommentsContainer}>
                  <MaterialIcons name="comment" size={48} color={COLORS.text.disabled} />
                  <Text style={styles.emptyCommentsText}>No comments yet</Text>
                  <Text style={styles.emptyCommentsSubtext}>Be the first to comment!</Text>
                </View>
              ) : (
                comments.map((comment) => (
                  <View key={comment.id} style={styles.commentItem}>
                    <View style={styles.commentAvatar}>
                      <Text style={styles.commentAvatarText}>
                        {comment.author?.charAt(0).toUpperCase() || 'U'}
                      </Text>
                    </View>
                    <View style={styles.commentContent}>
                      <View style={styles.commentHeader}>
                        <Text style={styles.commentAuthor}>{comment.author}</Text>
                        <Text style={styles.commentTime}>
                          {comment.timestamp ? formatTimeAgo(new Date(comment.timestamp)) : ''}
                        </Text>
                      </View>
                      <Text style={styles.commentText}>{comment.content}</Text>
                    </View>
                  </View>
                ))
              )}
            </ScrollView>

            {/* Comment Input */}
            <View style={styles.commentInputContainer}>
              <TextInput
                style={styles.commentInput}
                placeholder="Write a comment..."
                placeholderTextColor={COLORS.text.disabled}
                value={commentText}
                onChangeText={setCommentText}
                multiline
                maxLength={500}
              />
              <TouchableOpacity
                style={[
                  styles.postCommentButton,
                  (!commentText.trim() || postingComment) && styles.postCommentButtonDisabled
                ]}
                onPress={handlePostComment}
                disabled={!commentText.trim() || postingComment}
              >
                {postingComment ? (
                  <ActivityIndicator size="small" color={COLORS.white} />
                ) : (
                  <MaterialIcons name="send" size={20} color={COLORS.white} />
                )}
              </TouchableOpacity>
            </View>
          </View>
        </KeyboardAvoidingView>
      </Modal>

      {/* Share Modal */}
      <Modal
        visible={shareModalVisible}
        transparent
        animationType="fade"
        onRequestClose={handleCloseShareModal}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.shareModalContainer}>
            {/* Header */}
            <View style={styles.shareModalHeader}>
              <Text style={styles.shareModalTitle}>Share Post</Text>
              <TouchableOpacity onPress={handleCloseShareModal}>
                <MaterialIcons name="close" size={24} color={COLORS.text.primary} />
              </TouchableOpacity>
            </View>

            {/* Share Options */}
            <View style={styles.shareOptions}>
              <TouchableOpacity
                style={styles.shareOption}
                onPress={handleCopyLink}
              >
                <View style={styles.shareOptionIcon}>
                  <MaterialIcons name="link" size={28} color={COLORS.primary} />
                </View>
                <Text style={styles.shareOptionText}>Copy Link</Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={styles.shareOption}
                onPress={handleShareExternal}
              >
                <View style={styles.shareOptionIcon}>
                  <MaterialIcons name="share" size={28} color={COLORS.primary} />
                </View>
                <Text style={styles.shareOptionText}>Share Externally</Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={styles.shareOption}
                onPress={() => {
                  Alert.alert('Coming Soon', 'Share to team members feature coming soon!');
                  handleCloseShareModal();
                }}
              >
                <View style={styles.shareOptionIcon}>
                  <MaterialIcons name="group" size={28} color={COLORS.primary} />
                </View>
                <Text style={styles.shareOptionText}>Share to Team</Text>
              </TouchableOpacity>
            </View>

            {/* Cancel Button */}
            <TouchableOpacity
              style={styles.shareCancelButton}
              onPress={handleCloseShareModal}
            >
              <Text style={styles.shareCancelButtonText}>Cancel</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.backgroundSecondary,
  },
  tabContainer: {
    backgroundColor: COLORS.white,
    paddingVertical: SPACING.sm,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
  },
  tabScrollView: {
    paddingHorizontal: SPACING.lg,
  },
  tabButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: SPACING.lg,
    paddingVertical: SPACING.sm,
    marginRight: SPACING.sm,
    borderRadius: RADIUS.lg,
    backgroundColor: COLORS.background.secondary,
  },
  activeTabButton: {
    backgroundColor: COLORS.primary,
  },
  tabButtonText: {
    marginLeft: SPACING.xs,
    fontSize: TYPOGRAPHY.sm,
    fontWeight: TYPOGRAPHY.medium,
    color: COLORS.text.secondary,
  },
  activeTabButtonText: {
    color: COLORS.white,
  },
  content: {
    flex: 1,
  },
  tabContent: {
    padding: SPACING.lg,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.lg,
  },
  sectionTitle: {
    fontSize: TYPOGRAPHY['2xl'],
    fontWeight: TYPOGRAPHY.bold,
    color: COLORS.text.primary,
  },
  newsCard: {
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    ...SHADOWS.sm,
  },
  newsHeader: {
    marginBottom: SPACING.md,
  },
  authorInfo: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  authorAvatar: {
    width: 40,
    height: 40,
    borderRadius: RADIUS.full,
    backgroundColor: COLORS.primary,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: SPACING.sm,
  },
  authorInitial: {
    color: COLORS.white,
    fontSize: TYPOGRAPHY.lg,
    fontWeight: TYPOGRAPHY.bold,
  },
  authorName: {
    fontSize: TYPOGRAPHY.md,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.text.primary,
  },
  timestamp: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.text.secondary,
  },
  newsTitle: {
    fontSize: TYPOGRAPHY.lg,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.sm,
  },
  newsContent: {
    fontSize: TYPOGRAPHY.md,
    color: COLORS.text.secondary,
    lineHeight: 20,
    marginBottom: SPACING.md,
  },
  newsImage: {
    width: '100%',
    height: 200,
    borderRadius: RADIUS.md,
    marginBottom: SPACING.md,
  },
  newsActions: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    paddingTop: SPACING.sm,
    borderTopWidth: 1,
    borderTopColor: COLORS.border.light,
  },
  actionButton: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  actionText: {
    marginLeft: SPACING.xs,
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.text.secondary,
  },
  // Message styles
  messageCard: {
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    ...SHADOWS.sm,
  },
  unreadMessage: {
    borderLeftWidth: 4,
    borderLeftColor: COLORS.primary,
  },
  messageHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.sm,
  },
  senderInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  senderAvatar: {
    width: 36,
    height: 36,
    borderRadius: RADIUS.full,
    backgroundColor: COLORS.secondary,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: SPACING.sm,
  },
  senderInitial: {
    color: COLORS.white,
    fontSize: TYPOGRAPHY.md,
    fontWeight: TYPOGRAPHY.bold,
  },
  messageDetails: {
    flex: 1,
  },
  senderName: {
    fontSize: TYPOGRAPHY.md,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.text.primary,
  },
  messageTime: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.text.secondary,
  },
  unreadDot: {
    width: 8,
    height: 8,
    borderRadius: RADIUS.full,
    backgroundColor: COLORS.primary,
  },
  messageContent: {
    fontSize: TYPOGRAPHY.md,
    color: COLORS.text.secondary,
    lineHeight: 20,
  },
  // Trip styles
  tripCard: {
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    ...SHADOWS.sm,
  },
  tripHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  tripTitle: {
    fontSize: TYPOGRAPHY.lg,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.text.primary,
    flex: 1,
  },
  spotsIndicator: {
    backgroundColor: COLORS.background.secondary,
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.md,
  },
  spotsText: {
    fontSize: TYPOGRAPHY.sm,
    fontWeight: TYPOGRAPHY.medium,
    color: COLORS.text.primary,
  },
  tripDetails: {
    marginBottom: SPACING.md,
  },
  tripDetailRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.xs,
  },
  tripDetailText: {
    marginLeft: SPACING.sm,
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.text.secondary,
  },
  tripDescription: {
    fontSize: TYPOGRAPHY.md,
    color: COLORS.text.secondary,
    lineHeight: 20,
    marginBottom: SPACING.lg,
  },
  signupButton: {
    backgroundColor: COLORS.primary,
    paddingVertical: SPACING.md,
    borderRadius: RADIUS.md,
    alignItems: 'center',
  },
  disabledButton: {
    backgroundColor: COLORS.border.default,
  },
  signedUpButton: {
    backgroundColor: COLORS.success,
  },
  signupButtonText: {
    color: COLORS.white,
    fontSize: TYPOGRAPHY.md,
    fontWeight: TYPOGRAPHY.semibold,
  },
  disabledButtonText: {
    color: COLORS.text.disabled,
  },
  // Volunteer styles
  volunteerCard: {
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    marginBottom: SPACING.md,
    ...SHADOWS.sm,
  },
  volunteerHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.md,
  },
  volunteerInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  volunteerAvatar: {
    width: 40,
    height: 40,
    borderRadius: RADIUS.full,
    backgroundColor: COLORS.info,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: SPACING.sm,
  },
  volunteerInitial: {
    color: COLORS.white,
    fontSize: TYPOGRAPHY.lg,
    fontWeight: TYPOGRAPHY.bold,
  },
  volunteerName: {
    fontSize: TYPOGRAPHY.md,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.xs,
  },
  ratingContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  ratingText: {
    marginLeft: SPACING.xs,
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.text.secondary,
  },
  contactButton: {
    padding: SPACING.sm,
    borderRadius: RADIUS.md,
    backgroundColor: COLORS.background.secondary,
  },
  skillsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginBottom: SPACING.md,
  },
  skillTag: {
    backgroundColor: COLORS.primary + '20',
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.md,
    marginRight: SPACING.xs,
    marginBottom: SPACING.xs,
  },
  skillText: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.primary,
    fontWeight: TYPOGRAPHY.medium,
  },
  availabilityContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  availabilityText: {
    marginLeft: SPACING.xs,
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.text.secondary,
  },
  // Check-in styles
  checkinCard: {
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.lg,
    padding: SPACING.xl,
    marginBottom: SPACING.lg,
    alignItems: 'center',
    ...SHADOWS.sm,
  },
  checkinHeader: {
    alignItems: 'center',
    marginBottom: SPACING.lg,
  },
  checkinTitle: {
    fontSize: TYPOGRAPHY['2xl'],
    fontWeight: TYPOGRAPHY.bold,
    color: COLORS.text.primary,
    marginTop: SPACING.md,
  },
  checkinDescription: {
    fontSize: TYPOGRAPHY.md,
    color: COLORS.text.secondary,
    textAlign: 'center',
    lineHeight: 20,
    marginBottom: SPACING.lg,
  },
  checkinActions: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    width: '100%',
  },
  checkinButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: COLORS.primary,
    paddingVertical: SPACING.md,
    borderRadius: RADIUS.md,
    marginHorizontal: SPACING.xs,
  },
  secondaryButton: {
    backgroundColor: COLORS.white,
    borderWidth: 1,
    borderColor: COLORS.primary,
  },
  checkinButtonText: {
    color: COLORS.white,
    fontSize: TYPOGRAPHY.md,
    fontWeight: TYPOGRAPHY.semibold,
    marginLeft: SPACING.sm,
  },
  secondaryButtonText: {
    color: COLORS.primary,
  },
  recentCheckins: {
    backgroundColor: COLORS.white,
    borderRadius: RADIUS.lg,
    padding: SPACING.lg,
    ...SHADOWS.sm,
  },
  recentTitle: {
    fontSize: TYPOGRAPHY.lg,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.text.primary,
    marginBottom: SPACING.md,
  },
  checkinItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: SPACING.md,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
  },
  childInfo: {
    flex: 1,
  },
  childName: {
    fontSize: TYPOGRAPHY.md,
    fontWeight: TYPOGRAPHY.semibold,
    color: COLORS.text.primary,
  },
  checkinTime: {
    fontSize: TYPOGRAPHY.sm,
    color: COLORS.text.secondary,
    marginTop: SPACING.xs,
  },
  checkinStatus: {
    backgroundColor: COLORS.success + '20',
    paddingHorizontal: SPACING.sm,
    paddingVertical: SPACING.xs,
    borderRadius: RADIUS.md,
  },
  checkedOutStatus: {
    backgroundColor: COLORS.border.default,
  },
  statusText: {
    fontSize: TYPOGRAPHY.sm,
    fontWeight: TYPOGRAPHY.medium,
    color: COLORS.success,
  },
  checkedOutText: {
    color: COLORS.text.secondary,
  },
  // Empty state styles
  emptyState: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: SPACING['4xl'],
    paddingHorizontal: SPACING.xl,
  },
  emptyStateText: {
    fontSize: TYPOGRAPHY.lg,
    color: COLORS.text.disabled,
    marginTop: SPACING.lg,
    textAlign: 'center',
  },
  // Modal styles
  modalContainer: {
    flex: 1,
    justifyContent: 'flex-end',
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
  },
  modalContent: {
    backgroundColor: COLORS.white,
    borderTopLeftRadius: RADIUS.xl,
    borderTopRightRadius: RADIUS.xl,
    maxHeight: '90%',
    ...SHADOWS.lg,
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: SPACING.lg,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
  },
  modalTitle: {
    fontSize: TYPOGRAPHY['2xl'],
    fontWeight: TYPOGRAPHY.bold,
    color: COLORS.text.primary,
  },
  modalBody: {
    padding: SPACING.lg,
    maxHeight: 500,
  },
  formattingToolbar: {
    flexDirection: 'row',
    marginBottom: SPACING.md,
    paddingBottom: SPACING.sm,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
  },
  formatButton: {
    padding: SPACING.sm,
    borderRadius: RADIUS.md,
    marginRight: SPACING.sm,
    backgroundColor: COLORS.backgroundSecondary,
  },
  formatButtonActive: {
    backgroundColor: COLORS.primary,
  },
  postInput: {
    fontSize: TYPOGRAPHY.md,
    color: COLORS.text.primary,
    minHeight: 120,
    padding: SPACING.md,
    backgroundColor: COLORS.backgroundSecondary,
    borderRadius: RADIUS.md,
    marginBottom: SPACING.md,
  },
  imagePreview: {
    position: 'relative',
    marginBottom: SPACING.md,
  },
  previewImage: {
    width: '100%',
    height: 200,
    borderRadius: RADIUS.md,
  },
  removeImageButton: {
    position: 'absolute',
    top: SPACING.sm,
    right: SPACING.sm,
    backgroundColor: COLORS.white,
    borderRadius: 12,
  },
  imageUploadButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    padding: SPACING.md,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    borderRadius: RADIUS.md,
    borderStyle: 'dashed',
  },
  imageUploadText: {
    fontSize: TYPOGRAPHY.md,
    color: COLORS.primary,
    marginLeft: SPACING.sm,
    fontWeight: TYPOGRAPHY.medium,
  },
  modalFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    padding: SPACING.lg,
    borderTopWidth: 1,
    borderTopColor: COLORS.border.light,
  },
  cancelButton: {
    flex: 1,
    paddingVertical: SPACING.md,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    marginRight: SPACING.sm,
    alignItems: 'center',
  },
  cancelButtonText: {
    fontSize: TYPOGRAPHY.md,
    color: COLORS.text.secondary,
    fontWeight: TYPOGRAPHY.semibold,
  },
  submitButton: {
    flex: 1,
    paddingVertical: SPACING.md,
    borderRadius: RADIUS.md,
    backgroundColor: COLORS.primary,
    marginLeft: SPACING.sm,
    alignItems: 'center',
  },
  submitButtonText: {
    fontSize: TYPOGRAPHY.md,
    color: COLORS.white,
    fontWeight: TYPOGRAPHY.semibold,
  },
  // Comment Modal Styles
  commentModalContainer: {
    backgroundColor: COLORS.background.primary,
    borderTopLeftRadius: RADIUS.xl,
    borderTopRightRadius: RADIUS.xl,
    height: '80%',
    marginTop: 'auto',
    ...SHADOWS.large,
  },
  commentModalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: SPACING.lg,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.border.light,
  },
  commentModalTitle: {
    ...TYPOGRAPHY.h3,
    color: COLORS.text.primary,
    fontWeight: TYPOGRAPHY.bold,
  },
  commentsList: {
    flex: 1,
    padding: SPACING.md,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: SPACING.xl * 2,
  },
  loadingText: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.secondary,
    marginTop: SPACING.md,
  },
  emptyCommentsContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: SPACING.xl * 2,
  },
  emptyCommentsText: {
    ...TYPOGRAPHY.h4,
    color: COLORS.text.secondary,
    marginTop: SPACING.md,
  },
  emptyCommentsSubtext: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.disabled,
    marginTop: SPACING.xs,
  },
  commentItem: {
    flexDirection: 'row',
    marginBottom: SPACING.lg,
  },
  commentAvatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: COLORS.primary,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: SPACING.md,
  },
  commentAvatarText: {
    ...TYPOGRAPHY.body,
    color: COLORS.white,
    fontWeight: TYPOGRAPHY.bold,
  },
  commentContent: {
    flex: 1,
  },
  commentHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.xs,
  },
  commentAuthor: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.primary,
    fontWeight: TYPOGRAPHY.semibold,
  },
  commentTime: {
    ...TYPOGRAPHY.caption,
    color: COLORS.text.disabled,
  },
  commentText: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.secondary,
    lineHeight: 20,
  },
  commentInputContainer: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    padding: SPACING.md,
    borderTopWidth: 1,
    borderTopColor: COLORS.border.light,
    backgroundColor: COLORS.background.primary,
  },
  commentInput: {
    flex: 1,
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.lg,
    paddingHorizontal: SPACING.md,
    paddingVertical: SPACING.sm,
    marginRight: SPACING.sm,
    maxHeight: 100,
    ...TYPOGRAPHY.body,
    color: COLORS.text.primary,
  },
  postCommentButton: {
    backgroundColor: COLORS.primary,
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
  },
  postCommentButtonDisabled: {
    backgroundColor: COLORS.text.disabled,
  },
  // Share Modal Styles
  shareModalContainer: {
    backgroundColor: COLORS.background.primary,
    borderRadius: RADIUS.xl,
    margin: SPACING.xl,
    padding: SPACING.xl,
    ...SHADOWS.large,
  },
  shareModalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.xl,
  },
  shareModalTitle: {
    ...TYPOGRAPHY.h3,
    color: COLORS.text.primary,
    fontWeight: TYPOGRAPHY.bold,
  },
  shareOptions: {
    marginBottom: SPACING.lg,
  },
  shareOption: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: SPACING.lg,
    backgroundColor: COLORS.background.secondary,
    borderRadius: RADIUS.md,
    marginBottom: SPACING.md,
  },
  shareOptionIcon: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: COLORS.background.primary,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: SPACING.md,
  },
  shareOptionText: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.primary,
    fontWeight: TYPOGRAPHY.semibold,
  },
  shareCancelButton: {
    padding: SPACING.md,
    borderRadius: RADIUS.md,
    borderWidth: 1,
    borderColor: COLORS.border.default,
    alignItems: 'center',
  },
  shareCancelButtonText: {
    ...TYPOGRAPHY.body,
    color: COLORS.text.secondary,
    fontWeight: TYPOGRAPHY.semibold,
  },
});

export default CommunityScreen;
