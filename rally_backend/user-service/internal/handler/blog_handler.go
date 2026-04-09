package handler

import (
	"io"
	"net/http"
	"strconv"

	"rally-point/user-service/internal/domain"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type BlogHandler struct {
	blogService domain.BlogService
}

// NewBlogHandler creates a new blog handler
func NewBlogHandler(blogService domain.BlogService) *BlogHandler {
	return &BlogHandler{
		blogService: blogService,
	}
}

// CreateBlog handles creating a new blog post (admin only)
// POST /api/blogs
func (h *BlogHandler) CreateBlog(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user ID"})
		return
	}

	userRole := c.GetString("user_role")
	if !domain.IsAdminRole(userRole) {
		c.JSON(http.StatusForbidden, gin.H{"error": "only admins can create blogs"})
		return
	}

	var req domain.CreateBlogRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get author name from context (if available)
	authorName := c.GetString("user_name")

	blog, err := h.blogService.CreateBlog(userID, authorName, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, blog)
}

// GetBlog handles getting a single blog post
// GET /api/blogs/:id
func (h *BlogHandler) GetBlog(c *gin.Context) {
	blogIDStr := c.Param("id")
	blogID, err := uuid.Parse(blogIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid blog ID"})
		return
	}

	// Increment view count for regular users
	incrementView := true

	blog, err := h.blogService.GetBlog(blogID, incrementView)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "blog not found"})
		return
	}

	// Check if unpublished blog should be visible
	if !blog.IsPublished {
		userRole := c.GetString("user_role")
		if !domain.IsAdminRole(userRole) {
			c.JSON(http.StatusNotFound, gin.H{"error": "blog not found"})
			return
		}
	}

	c.JSON(http.StatusOK, blog)
}

// ListBlogs handles listing all blogs with pagination
// GET /api/blogs
func (h *BlogHandler) ListBlogs(c *gin.Context) {
	// Parse pagination parameters
	pageStr := c.DefaultQuery("page", "1")
	pageSizeStr := c.DefaultQuery("page_size", "10")

	page, err := strconv.Atoi(pageStr)
	if err != nil || page < 1 {
		page = 1
	}

	pageSize, err := strconv.Atoi(pageSizeStr)
	if err != nil || pageSize < 1 {
		pageSize = 10
	}

	// Check if showing unpublished blogs (admin only)
	publishedOnly := true
	showAllStr := c.Query("show_all")
	if showAllStr == "true" {
		userRole := c.GetString("user_role")
		if domain.IsAdminRole(userRole) {
			publishedOnly = false
		}
	}

	response, err := h.blogService.ListBlogs(page, pageSize, publishedOnly)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, response)
}

// UpdateBlog handles updating a blog post (admin only)
// PUT /api/blogs/:id
func (h *BlogHandler) UpdateBlog(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user ID"})
		return
	}

	userRole := c.GetString("user_role")
	if !domain.IsAdminRole(userRole) {
		c.JSON(http.StatusForbidden, gin.H{"error": "only admins can update blogs"})
		return
	}

	blogIDStr := c.Param("id")
	blogID, err := uuid.Parse(blogIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid blog ID"})
		return
	}

	var req domain.UpdateBlogRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	blog, err := h.blogService.UpdateBlog(blogID, userID, &req)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, blog)
}

// DeleteBlog handles deleting a blog post (admin only)
// DELETE /api/blogs/:id
func (h *BlogHandler) DeleteBlog(c *gin.Context) {
	userIDStr := c.GetString("user_id")
	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid user ID"})
		return
	}

	userRole := c.GetString("user_role")
	if !domain.IsAdminRole(userRole) {
		c.JSON(http.StatusForbidden, gin.H{"error": "only admins can delete blogs"})
		return
	}

	blogIDStr := c.Param("id")
	blogID, err := uuid.Parse(blogIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid blog ID"})
		return
	}

	err = h.blogService.DeleteBlog(blogID, userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Blog deleted successfully"})
}

// UploadImage handles uploading an image for a blog post (admin only)
// POST /api/blogs/:id/image
func (h *BlogHandler) UploadImage(c *gin.Context) {
	userRole := c.GetString("user_role")
	if !domain.IsAdminRole(userRole) {
		c.JSON(http.StatusForbidden, gin.H{"error": "only admins can upload images"})
		return
	}

	blogIDStr := c.Param("id")
	blogID, err := uuid.Parse(blogIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid blog ID"})
		return
	}

	// Parse multipart form (10MB max)
	err = c.Request.ParseMultipartForm(10 * 1024 * 1024)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "failed to parse form"})
		return
	}

	// Get image file
	file, header, err := c.Request.FormFile("image")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "no image file provided"})
		return
	}
	defer file.Close()

	// Read image data
	imageData, err := io.ReadAll(file)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "failed to read image file"})
		return
	}

	imageURL, err := h.blogService.UploadImage(blogID, imageData, header.Filename)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"image_url": imageURL,
		"blog_id":   blogID,
	})
}

// UploadImageDirect handles uploading an image without a blog ID (for creating new blogs)
// POST /api/blogs/upload-image
func (h *BlogHandler) UploadImageDirect(c *gin.Context) {
	userRole := c.GetString("user_role")
	if !domain.IsAdminRole(userRole) {
		c.JSON(http.StatusForbidden, gin.H{"error": "only admins can upload images"})
		return
	}

	// Parse multipart form (10MB max)
	err := c.Request.ParseMultipartForm(10 * 1024 * 1024)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "failed to parse form"})
		return
	}

	// Get image file
	file, header, err := c.Request.FormFile("image")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "no image file provided"})
		return
	}
	defer file.Close()

	// Read image data
	imageData, err := io.ReadAll(file)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "failed to read image file"})
		return
	}

	// Use a temporary blog ID for the filename
	tempID := uuid.New()
	imageURL, err := h.blogService.UploadImage(tempID, imageData, header.Filename)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"image_url": imageURL,
	})
}
