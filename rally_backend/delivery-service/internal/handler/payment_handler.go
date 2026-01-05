package handler

import (
	"fmt"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/stripe/stripe-go/v76"
	"github.com/stripe/stripe-go/v76/checkout/session"
	"github.com/stripe/stripe-go/v76/paymentintent"
	"github.com/twilio/twilio-go"
	openapi "github.com/twilio/twilio-go/rest/api/v2010"
)

// PaymentHandler handles payment-related HTTP requests
type PaymentHandler struct {
	stripeSecretKey   string
	twilioAccountSID  string
	twilioAuthToken   string
	twilioPhoneNumber string
	twilioClient      *twilio.RestClient
	debugMode         bool // When true, bypasses Stripe/Twilio and simulates success
	// In-memory store for payment sessions (in production, use Redis or DB)
	paymentSessions     map[string]*PaymentSession
	paymentSessionsLock sync.RWMutex
}

// PaymentSession tracks a payment link session
type PaymentSession struct {
	ID              string    `json:"id"`
	DeliveryID      string    `json:"delivery_id"`
	RecipientPhone  string    `json:"recipient_phone"`
	Amount          int64     `json:"amount"` // in cents
	Currency        string    `json:"currency"`
	Status          string    `json:"status"` // pending, completed, failed, expired
	StripeSessionID string    `json:"stripe_session_id"`
	PaymentURL      string    `json:"payment_url"`
	SMSSent         bool      `json:"sms_sent"`
	CreatedAt       time.Time `json:"created_at"`
	UpdatedAt       time.Time `json:"updated_at"`
	CompletedAt     *time.Time `json:"completed_at,omitempty"`
}

// NewPaymentHandler creates a new payment handler
func NewPaymentHandler() *PaymentHandler {
	// Check for debug mode - bypasses Stripe/Twilio for testing
	debugMode := os.Getenv("DEBUG_BYPASS_PAYMENT") == "true"

	secretKey := os.Getenv("STRIPE_SECRET_KEY")
	if secretKey == "" {
		secretKey = "sk_test_placeholder" // Replace with actual test key
	}
	stripe.Key = secretKey

	twilioAccountSID := os.Getenv("TWILIO_ACCOUNT_SID")
	twilioAuthToken := os.Getenv("TWILIO_AUTH_TOKEN")
	twilioPhoneNumber := os.Getenv("TWILIO_PHONE_NUMBER")

	var twilioClient *twilio.RestClient
	if twilioAccountSID != "" && twilioAuthToken != "" && !debugMode {
		twilioClient = twilio.NewRestClientWithParams(twilio.ClientParams{
			Username: twilioAccountSID,
			Password: twilioAuthToken,
		})
	}

	if debugMode {
		fmt.Println("⚠️  Payment handler running in DEBUG MODE - Stripe/Twilio bypassed")
	}

	return &PaymentHandler{
		stripeSecretKey:   secretKey,
		twilioAccountSID:  twilioAccountSID,
		twilioAuthToken:   twilioAuthToken,
		twilioPhoneNumber: twilioPhoneNumber,
		twilioClient:      twilioClient,
		debugMode:         debugMode,
		paymentSessions:   make(map[string]*PaymentSession),
	}
}

// CreatePaymentIntentRequest represents the request to create a payment intent
type CreatePaymentIntentRequest struct {
	Amount      int64             `json:"amount" binding:"required,min=50"` // Amount in cents, min $0.50
	Currency    string            `json:"currency"`
	Description string            `json:"description"`
	Metadata    map[string]string `json:"metadata"`
}

// CreatePaymentIntentResponse represents the response from creating a payment intent
type CreatePaymentIntentResponse struct {
	ClientSecret    string `json:"client_secret"`
	PaymentIntentID string `json:"payment_intent_id"`
}

// CreatePaymentIntent creates a new Stripe PaymentIntent
func (h *PaymentHandler) CreatePaymentIntent(c *gin.Context) {
	var req CreatePaymentIntentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Default currency to USD
	currency := req.Currency
	if currency == "" {
		currency = "usd"
	}

	// Create PaymentIntent
	params := &stripe.PaymentIntentParams{
		Amount:   stripe.Int64(req.Amount),
		Currency: stripe.String(currency),
		AutomaticPaymentMethods: &stripe.PaymentIntentAutomaticPaymentMethodsParams{
			Enabled: stripe.Bool(true),
		},
	}

	if req.Description != "" {
		params.Description = stripe.String(req.Description)
	}

	if len(req.Metadata) > 0 {
		params.Metadata = make(map[string]string)
		for k, v := range req.Metadata {
			params.Metadata[k] = v
		}
	}

	pi, err := paymentintent.New(params)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to create payment intent: %v", err)})
		return
	}

	c.JSON(http.StatusOK, CreatePaymentIntentResponse{
		ClientSecret:    pi.ClientSecret,
		PaymentIntentID: pi.ID,
	})
}

// VerifyPayment verifies a payment was successful
func (h *PaymentHandler) VerifyPayment(c *gin.Context) {
	paymentIntentID := c.Param("id")
	if paymentIntentID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Payment intent ID is required"})
		return
	}

	pi, err := paymentintent.Get(paymentIntentID, nil)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Payment intent not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"payment_intent_id": pi.ID,
		"status":            string(pi.Status),
		"amount":            pi.Amount,
		"currency":          string(pi.Currency),
	})
}

// SendPaymentLinkRequest represents request to send payment link via SMS
type SendPaymentLinkRequest struct {
	DeliveryID     string `json:"delivery_id"`
	RecipientPhone string `json:"recipient_phone" binding:"required"`
	RecipientName  string `json:"recipient_name"`
	Amount         int64  `json:"amount" binding:"required,min=50"` // Amount in cents
	Currency       string `json:"currency"`
	Description    string `json:"description"`
}

// SendPaymentLinkResponse represents response after sending payment link
type SendPaymentLinkResponse struct {
	SessionID   string `json:"session_id"`
	PaymentURL  string `json:"payment_url"`
	SMSSent     bool   `json:"sms_sent"`
	SMSError    string `json:"sms_error,omitempty"`
	Status      string `json:"status"`
}

// SendPaymentLink creates a Stripe Checkout Session and sends the link via SMS
func (h *PaymentHandler) SendPaymentLink(c *gin.Context) {
	var req SendPaymentLinkRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Default currency to USD
	currency := req.Currency
	if currency == "" {
		currency = "usd"
	}

	// Create a unique session ID for tracking
	sessionID := uuid.New().String()

	// DEBUG MODE: Skip Stripe and Twilio, return fake success
	if h.debugMode {
		// Store a fake payment session that will auto-complete on status check
		paymentSession := &PaymentSession{
			ID:              sessionID,
			DeliveryID:      req.DeliveryID,
			RecipientPhone:  req.RecipientPhone,
			Amount:          req.Amount,
			Currency:        currency,
			Status:          "pending",
			StripeSessionID: "debug_cs_" + sessionID,
			PaymentURL:      "https://debug.stripe.com/pay/" + sessionID,
			SMSSent:         true, // Fake SMS sent
			CreatedAt:       time.Now(),
			UpdatedAt:       time.Now(),
		}

		h.paymentSessionsLock.Lock()
		h.paymentSessions[sessionID] = paymentSession
		h.paymentSessionsLock.Unlock()

		c.JSON(http.StatusOK, SendPaymentLinkResponse{
			SessionID:  sessionID,
			PaymentURL: paymentSession.PaymentURL,
			SMSSent:    true,
			SMSError:   "",
			Status:     "pending",
		})
		return
	}

	// Description for the payment
	description := req.Description
	if description == "" {
		description = "Donation/Book Purchase"
	}

	// Success and cancel URLs - these would be your actual hosted pages
	successURL := fmt.Sprintf("https://rally-point.app/payment/success?session=%s", sessionID)
	cancelURL := fmt.Sprintf("https://rally-point.app/payment/cancel?session=%s", sessionID)

	// Create Stripe Checkout Session
	checkoutParams := &stripe.CheckoutSessionParams{
		PaymentMethodTypes: stripe.StringSlice([]string{"card"}),
		LineItems: []*stripe.CheckoutSessionLineItemParams{
			{
				PriceData: &stripe.CheckoutSessionLineItemPriceDataParams{
					Currency: stripe.String(currency),
					ProductData: &stripe.CheckoutSessionLineItemPriceDataProductDataParams{
						Name:        stripe.String(description),
						Description: stripe.String("Thank you for your generous contribution"),
					},
					UnitAmount: stripe.Int64(req.Amount),
				},
				Quantity: stripe.Int64(1),
			},
		},
		Mode:       stripe.String(string(stripe.CheckoutSessionModePayment)),
		SuccessURL: stripe.String(successURL),
		CancelURL:  stripe.String(cancelURL),
		Metadata: map[string]string{
			"session_id":  sessionID,
			"delivery_id": req.DeliveryID,
		},
	}

	// Add customer email if phone can be formatted as email (optional)
	if req.RecipientName != "" {
		checkoutParams.Metadata["recipient_name"] = req.RecipientName
	}

	checkoutSession, err := session.New(checkoutParams)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Failed to create checkout session: %v", err)})
		return
	}

	// Store the payment session for tracking
	paymentSession := &PaymentSession{
		ID:              sessionID,
		DeliveryID:      req.DeliveryID,
		RecipientPhone:  req.RecipientPhone,
		Amount:          req.Amount,
		Currency:        currency,
		Status:          "pending",
		StripeSessionID: checkoutSession.ID,
		PaymentURL:      checkoutSession.URL,
		SMSSent:         false,
		CreatedAt:       time.Now(),
		UpdatedAt:       time.Now(),
	}

	h.paymentSessionsLock.Lock()
	h.paymentSessions[sessionID] = paymentSession
	h.paymentSessionsLock.Unlock()

	// Send SMS with payment link
	var smsError string
	smsSent := false

	if h.twilioClient != nil && h.twilioPhoneNumber != "" {
		smsMessage := fmt.Sprintf(
			"Hi! You have a payment request for $%.2f. Please complete your payment here: %s",
			float64(req.Amount)/100,
			checkoutSession.URL,
		)

		params := &openapi.CreateMessageParams{}
		params.SetTo(req.RecipientPhone)
		params.SetFrom(h.twilioPhoneNumber)
		params.SetBody(smsMessage)

		_, err := h.twilioClient.Api.CreateMessage(params)
		if err != nil {
			smsError = fmt.Sprintf("Failed to send SMS: %v", err)
		} else {
			smsSent = true
		}
	} else {
		smsError = "Twilio not configured - SMS not sent"
	}

	// Update session with SMS status
	h.paymentSessionsLock.Lock()
	paymentSession.SMSSent = smsSent
	h.paymentSessionsLock.Unlock()

	c.JSON(http.StatusOK, SendPaymentLinkResponse{
		SessionID:  sessionID,
		PaymentURL: checkoutSession.URL,
		SMSSent:    smsSent,
		SMSError:   smsError,
		Status:     "pending",
	})
}

// GetPaymentStatusResponse represents payment status response
type GetPaymentStatusResponse struct {
	SessionID   string     `json:"session_id"`
	Status      string     `json:"status"` // pending, completed, failed, expired
	Amount      int64      `json:"amount"`
	Currency    string     `json:"currency"`
	SMSSent     bool       `json:"sms_sent"`
	CompletedAt *time.Time `json:"completed_at,omitempty"`
}

// GetPaymentStatus checks the status of a payment session (for polling)
func (h *PaymentHandler) GetPaymentStatus(c *gin.Context) {
	sessionID := c.Param("sessionId")
	if sessionID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Session ID is required"})
		return
	}

	// Get session from our store
	h.paymentSessionsLock.RLock()
	paymentSession, exists := h.paymentSessions[sessionID]
	h.paymentSessionsLock.RUnlock()

	if !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "Payment session not found"})
		return
	}

	// If already completed or failed, return cached status
	if paymentSession.Status == "completed" || paymentSession.Status == "failed" {
		c.JSON(http.StatusOK, GetPaymentStatusResponse{
			SessionID:   paymentSession.ID,
			Status:      paymentSession.Status,
			Amount:      paymentSession.Amount,
			Currency:    paymentSession.Currency,
			SMSSent:     paymentSession.SMSSent,
			CompletedAt: paymentSession.CompletedAt,
		})
		return
	}

	// DEBUG MODE: Auto-complete after 5 seconds from creation
	if h.debugMode {
		elapsed := time.Since(paymentSession.CreatedAt)
		if elapsed > 5*time.Second {
			// Auto-complete the payment
			now := time.Now()
			h.paymentSessionsLock.Lock()
			paymentSession.Status = "completed"
			paymentSession.CompletedAt = &now
			paymentSession.UpdatedAt = now
			h.paymentSessionsLock.Unlock()

			c.JSON(http.StatusOK, GetPaymentStatusResponse{
				SessionID:   paymentSession.ID,
				Status:      "completed",
				Amount:      paymentSession.Amount,
				Currency:    paymentSession.Currency,
				SMSSent:     paymentSession.SMSSent,
				CompletedAt: &now,
			})
			return
		}

		// Still pending
		c.JSON(http.StatusOK, GetPaymentStatusResponse{
			SessionID: paymentSession.ID,
			Status:    "pending",
			Amount:    paymentSession.Amount,
			Currency:  paymentSession.Currency,
			SMSSent:   paymentSession.SMSSent,
		})
		return
	}

	// Check with Stripe for latest status
	stripeSession, err := session.Get(paymentSession.StripeSessionID, nil)
	if err != nil {
		c.JSON(http.StatusOK, GetPaymentStatusResponse{
			SessionID: paymentSession.ID,
			Status:    "pending",
			Amount:    paymentSession.Amount,
			Currency:  paymentSession.Currency,
			SMSSent:   paymentSession.SMSSent,
		})
		return
	}

	// Map Stripe status to our status
	var status string
	switch stripeSession.PaymentStatus {
	case stripe.CheckoutSessionPaymentStatusPaid:
		status = "completed"
		now := time.Now()
		h.paymentSessionsLock.Lock()
		paymentSession.Status = status
		paymentSession.CompletedAt = &now
		paymentSession.UpdatedAt = now
		h.paymentSessionsLock.Unlock()
	case stripe.CheckoutSessionPaymentStatusUnpaid:
		// Check if session is expired
		if stripeSession.Status == stripe.CheckoutSessionStatusExpired {
			status = "expired"
			h.paymentSessionsLock.Lock()
			paymentSession.Status = status
			paymentSession.UpdatedAt = time.Now()
			h.paymentSessionsLock.Unlock()
		} else {
			status = "pending"
		}
	default:
		status = "pending"
	}

	c.JSON(http.StatusOK, GetPaymentStatusResponse{
		SessionID:   paymentSession.ID,
		Status:      status,
		Amount:      paymentSession.Amount,
		Currency:    paymentSession.Currency,
		SMSSent:     paymentSession.SMSSent,
		CompletedAt: paymentSession.CompletedAt,
	})
}

// HandleWebhook handles Stripe webhooks for payment events
func (h *PaymentHandler) HandleWebhook(c *gin.Context) {
	// TODO: Implement webhook handling for payment confirmations
	// This would update delivery records when payments are confirmed
	// For production, verify webhook signature using stripe.WebhookEndpointSecret
	c.JSON(http.StatusOK, gin.H{"received": true})
}
