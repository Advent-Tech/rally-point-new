package notification

import (
	"context"
	"fmt"
	"log"
	"os"
	"strings"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"google.golang.org/api/option"
)

// FCMSender sends push notifications via Firebase Cloud Messaging
type FCMSender struct {
	client *messaging.Client
}

// NewFCMSender initializes the FCM client from environment variables
func NewFCMSender() (*FCMSender, error) {
	projectID := os.Getenv("FIREBASE_PROJECT_ID")
	privateKey := os.Getenv("FIREBASE_PRIVATE_KEY")
	clientEmail := os.Getenv("FIREBASE_CLIENT_EMAIL")

	if projectID == "" || privateKey == "" || clientEmail == "" {
		return nil, fmt.Errorf("missing Firebase configuration (FIREBASE_PROJECT_ID, FIREBASE_PRIVATE_KEY, FIREBASE_CLIENT_EMAIL)")
	}

	// Unescape the private key (env vars have literal \n)
	privateKey = strings.ReplaceAll(privateKey, "\\n", "\n")

	// Build service account JSON from env vars
	serviceAccountJSON := fmt.Sprintf(`{
		"type": "service_account",
		"project_id": %q,
		"private_key": %q,
		"client_email": %q,
		"token_uri": "https://oauth2.googleapis.com/token"
	}`, projectID, privateKey, clientEmail)

	opt := option.WithCredentialsJSON([]byte(serviceAccountJSON))
	app, err := firebase.NewApp(context.Background(), nil, opt)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize Firebase app: %w", err)
	}

	client, err := app.Messaging(context.Background())
	if err != nil {
		return nil, fmt.Errorf("failed to get Firebase Messaging client: %w", err)
	}

	return &FCMSender{client: client}, nil
}

// SendToUser sends a push notification to all active devices of a user.
// Returns the list of stale tokens that should be deactivated.
func (f *FCMSender) SendToUser(ctx context.Context, tokens []DeviceToken, title, body string, data map[string]string) []string {
	if len(tokens) == 0 {
		return nil
	}

	tokenStrings := make([]string, len(tokens))
	for i, t := range tokens {
		tokenStrings[i] = t.Token
	}

	msg := &messaging.MulticastMessage{
		Tokens: tokenStrings,
		Notification: &messaging.Notification{
			Title: title,
			Body:  body,
		},
		Data: data,
		Android: &messaging.AndroidConfig{
			Priority: "high",
			Notification: &messaging.AndroidNotification{
				ChannelID: channelForType(data["notification_type"]),
				Sound:     "default",
			},
		},
		APNS: &messaging.APNSConfig{
			Headers: map[string]string{
				"apns-priority": "10",
			},
			Payload: &messaging.APNSPayload{
				Aps: &messaging.Aps{
					Sound: "default",
				},
			},
		},
	}

	response, err := f.client.SendEachForMulticast(ctx, msg)
	if err != nil {
		log.Printf("FCM multicast error: %v", err)
		return nil
	}

	// Collect stale tokens for cleanup
	var staleTokens []string
	if response.FailureCount > 0 {
		for i, resp := range response.Responses {
			if resp.Error != nil {
				if messaging.IsUnregistered(resp.Error) || messaging.IsInvalidArgument(resp.Error) {
					staleTokens = append(staleTokens, tokenStrings[i])
				}
				log.Printf("FCM send error for token %s: %v", tokenStrings[i][:20], resp.Error)
			}
		}
	}

	log.Printf("FCM sent: %d success, %d failures", response.SuccessCount, response.FailureCount)
	return staleTokens
}

func channelForType(notifType string) string {
	switch notifType {
	case "geofence":
		return "geofence_channel"
	case "prayer":
		return "prayer_channel"
	case "delivery":
		return "delivery_channel"
	case "book_sale":
		return "book_sale_channel"
	case "team":
		return "team_channel"
	case "walkie":
		return "walkie_channel"
	case "chat":
		return "chat_channel"
	case "session":
		return "session_channel"
	default:
		return "default_channel"
	}
}
