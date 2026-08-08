package email

import (
	"bytes"
	"html/template"
	"os"
)

// EmailTemplates holds all email template generators
type EmailTemplates struct {
	frontendURL string
	backendURL  string
}

// NewEmailTemplates creates a new template generator
func NewEmailTemplates() *EmailTemplates {
	frontendURL := os.Getenv("FRONTEND_URL")
	if frontendURL == "" {
		frontendURL = "http://localhost:3000"
	}
	backendURL := os.Getenv("BASE_URL")
	if backendURL == "" {
		backendURL = "http://localhost:8081"
	}
	return &EmailTemplates{
		frontendURL: frontendURL,
		backendURL:  backendURL,
	}
}

// VerificationEmailData holds data for verification email
type VerificationEmailData struct {
	UserName        string
	VerificationURL string
	ExpiryHours     int
}

// PasswordResetEmailData holds data for password reset email
type PasswordResetEmailData struct {
	UserName      string
	ResetURL      string
	ExpiryMinutes int
}

// TeamInvitationEmailData holds data for team invitation email
type TeamInvitationEmailData struct {
	InviterName   string
	TeamName      string
	InviteeEmail  string
	InvitationURL string
	ExpiryDays    int
}

// GenerateVerificationEmail generates HTML and text versions of verification email
func (t *EmailTemplates) GenerateVerificationEmail(data VerificationEmailData) (html, text string, err error) {
	htmlTmpl := `<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            line-height: 1.6;
            color: #333;
            margin: 0;
            padding: 0;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            background-color: #4A90D9;
            color: white;
            padding: 30px 20px;
            text-align: center;
            border-radius: 8px 8px 0 0;
        }
        .header h1 {
            margin: 0;
            font-size: 28px;
            font-weight: 600;
        }
        .content {
            padding: 30px;
            background-color: #ffffff;
            border-radius: 0 0 8px 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .content h2 {
            color: #333;
            margin-top: 0;
        }
        .button {
            display: inline-block;
            background-color: #4A90D9;
            color: white !important;
            padding: 14px 28px;
            text-decoration: none;
            border-radius: 6px;
            margin: 20px 0;
            font-weight: 600;
            font-size: 16px;
        }
        .button:hover {
            background-color: #357ABD;
        }
        .link-text {
            word-break: break-all;
            color: #666;
            font-size: 14px;
            background-color: #f9f9f9;
            padding: 10px;
            border-radius: 4px;
            margin: 10px 0;
        }
        .footer {
            padding: 20px;
            text-align: center;
            color: #666;
            font-size: 12px;
        }
        .warning {
            background-color: #FFF3CD;
            border: 1px solid #FFE69C;
            padding: 12px;
            border-radius: 6px;
            margin-top: 20px;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>light point</h1>
        </div>
        <div class="content">
            <h2>Verify Your Email Address</h2>
            <p>Hello {{.UserName}},</p>
            <p>Thank you for registering with light point. To complete your registration, please activate your account by clicking the button below:</p>
            <table role="presentation" cellspacing="0" cellpadding="0" border="0" style="margin:20px auto;">
                <tr>
                    <td align="center" bgcolor="#4A90D9" style="border-radius:6px;">
                        <a href="{{.VerificationURL}}" style="display:inline-block;padding:14px 28px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;font-size:16px;font-weight:600;color:#ffffff;text-decoration:none;border-radius:6px;">Activate Account</a>
                    </td>
                </tr>
            </table>
            <div class="warning">
                <strong>Note:</strong> This link will expire in {{.ExpiryHours}} hours. If you did not create an account with light point, please ignore this email.
            </div>
        </div>
        <div class="footer">
            <p>&copy; light point. All rights reserved.</p>
            <p>This is an automated message, please do not reply.</p>
        </div>
    </div>
</body>
</html>`

	textTmpl := `light point - Verify Your Email Address

Hello {{.UserName}},

Thank you for registering with light point. To complete your registration, please activate your account by clicking the link below:

{{.VerificationURL}}

This link will expire in {{.ExpiryHours}} hours.

If you did not create an account with light point, please ignore this email.

---
light point
This is an automated message, please do not reply.`

	var htmlBuf, textBuf bytes.Buffer

	htmlTemplate, err := template.New("html").Parse(htmlTmpl)
	if err != nil {
		return "", "", err
	}
	if err = htmlTemplate.Execute(&htmlBuf, data); err != nil {
		return "", "", err
	}

	textTemplate, err := template.New("text").Parse(textTmpl)
	if err != nil {
		return "", "", err
	}
	if err = textTemplate.Execute(&textBuf, data); err != nil {
		return "", "", err
	}

	return htmlBuf.String(), textBuf.String(), nil
}

// GeneratePasswordResetEmail generates HTML and text versions of password reset email
func (t *EmailTemplates) GeneratePasswordResetEmail(data PasswordResetEmailData) (html, text string, err error) {
	htmlTmpl := `<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            line-height: 1.6;
            color: #333;
            margin: 0;
            padding: 0;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            background-color: #4A90D9;
            color: white;
            padding: 30px 20px;
            text-align: center;
            border-radius: 8px 8px 0 0;
        }
        .header h1 {
            margin: 0;
            font-size: 28px;
            font-weight: 600;
        }
        .content {
            padding: 30px;
            background-color: #ffffff;
            border-radius: 0 0 8px 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .content h2 {
            color: #333;
            margin-top: 0;
        }
        .button {
            display: inline-block;
            background-color: #E74C3C;
            color: white !important;
            padding: 14px 28px;
            text-decoration: none;
            border-radius: 6px;
            margin: 20px 0;
            font-weight: 600;
            font-size: 16px;
        }
        .button:hover {
            background-color: #C0392B;
        }
        .link-text {
            word-break: break-all;
            color: #666;
            font-size: 14px;
            background-color: #f9f9f9;
            padding: 10px;
            border-radius: 4px;
            margin: 10px 0;
        }
        .footer {
            padding: 20px;
            text-align: center;
            color: #666;
            font-size: 12px;
        }
        .warning {
            background-color: #FDEDEC;
            border: 1px solid #F5B7B1;
            padding: 12px;
            border-radius: 6px;
            margin-top: 20px;
            font-size: 14px;
        }
        .security-notice {
            background-color: #FFF3CD;
            border: 1px solid #FFE69C;
            padding: 12px;
            border-radius: 6px;
            margin-top: 15px;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>light point</h1>
        </div>
        <div class="content">
            <h2>Reset Your Password</h2>
            <p>Hello {{.UserName}},</p>
            <p>We received a request to reset your password. Click the button below to create a new password:</p>
            <p style="text-align: center;">
                <a href="{{.ResetURL}}" class="button">Reset Password</a>
            </p>
            <p>Or copy and paste this link into your browser:</p>
            <p class="link-text">{{.ResetURL}}</p>
            <div class="warning">
                <strong>Security Notice:</strong> This link will expire in {{.ExpiryMinutes}} minutes for your security.
            </div>
            <div class="security-notice">
                <strong>Didn't request this?</strong> If you did not request a password reset, please ignore this email. Your password will remain unchanged and your account is secure.
            </div>
        </div>
        <div class="footer">
            <p>&copy; light point. All rights reserved.</p>
            <p>This is an automated message, please do not reply.</p>
        </div>
    </div>
</body>
</html>`

	textTmpl := `Light Point - Reset Your Password

Hello {{.UserName}},

We received a request to reset your password. Click the link below to create a new password:

>>> Reset Password <<<
{{.ResetURL}}

(If the above link doesn't work, copy and paste the URL into your browser.)

This link will expire in {{.ExpiryMinutes}} minutes for your security.

Didn't request this? If you did not request a password reset, please ignore this email. Your password will remain unchanged and your account is secure.

---
Light Point
This is an automated message, please do not reply.`

	var htmlBuf, textBuf bytes.Buffer

	htmlTemplate, err := template.New("html").Parse(htmlTmpl)
	if err != nil {
		return "", "", err
	}
	if err = htmlTemplate.Execute(&htmlBuf, data); err != nil {
		return "", "", err
	}

	textTemplate, err := template.New("text").Parse(textTmpl)
	if err != nil {
		return "", "", err
	}
	if err = textTemplate.Execute(&textBuf, data); err != nil {
		return "", "", err
	}

	return htmlBuf.String(), textBuf.String(), nil
}

// GetVerificationURL constructs the full verification URL
func (t *EmailTemplates) GetVerificationURL(token string) string {
	return t.backendURL + "/api/auth/verify-email/" + token
}

// GetPasswordResetURL constructs the full password reset URL
func (t *EmailTemplates) GetPasswordResetURL(token string) string {
	return t.frontendURL + "/reset-password/" + token
}

// SetFrontendURL allows updating the frontend URL (useful for testing)
func (t *EmailTemplates) SetFrontendURL(url string) {
	t.frontendURL = url
}

// GetTeamInvitationURL constructs the full team invitation URL
func (t *EmailTemplates) GetTeamInvitationURL(token string) string {
	return t.backendURL + "/api/invitations/join/" + token
}

// AdminInvitationEmailData holds data for admin invitation email
type AdminInvitationEmailData struct {
	InviterName    string
	InviteeEmail   string
	Role           string
	InvitationURL  string
	ExpiryDays     int
}

// GetAdminInvitationURL constructs the full admin invitation URL (points to password reset screen)
func (t *EmailTemplates) GetAdminInvitationURL(token string) string {
	return t.frontendURL + "/reset-password/" + token
}

// GenerateAdminInvitationEmail generates HTML and text versions of admin invitation email
func (t *EmailTemplates) GenerateAdminInvitationEmail(data AdminInvitationEmailData) (html, text string, err error) {
	roleLabel := "Admin"
	if data.Role == "superadmin" {
		roleLabel = "Superadmin"
	}

	htmlTmpl := `<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            line-height: 1.6;
            color: #333;
            margin: 0;
            padding: 0;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px 20px;
            text-align: center;
            border-radius: 8px 8px 0 0;
        }
        .header h1 {
            margin: 0;
            font-size: 28px;
            font-weight: 600;
        }
        .content {
            padding: 30px;
            background-color: #ffffff;
            border-radius: 0 0 8px 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .content h2 {
            color: #333;
            margin-top: 0;
        }
        .role-badge {
            display: inline-block;
            background: linear-gradient(135deg, #667eea15 0%, #764ba215 100%);
            border: 1px solid #667eea30;
            border-radius: 20px;
            padding: 8px 20px;
            margin: 15px 0;
            font-weight: 600;
            color: #667eea;
            font-size: 16px;
        }
        .button {
            display: inline-block;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white !important;
            padding: 14px 32px;
            text-decoration: none;
            border-radius: 8px;
            margin: 20px 0;
            font-weight: 600;
            font-size: 16px;
        }
        .button:hover {
            opacity: 0.9;
        }
        .link-text {
            word-break: break-all;
            color: #666;
            font-size: 14px;
            background-color: #f9f9f9;
            padding: 10px;
            border-radius: 4px;
            margin: 10px 0;
        }
        .footer {
            padding: 20px;
            text-align: center;
            color: #666;
            font-size: 12px;
        }
        .info-box {
            background-color: #E8F4FD;
            border: 1px solid #B3D9F7;
            padding: 12px;
            border-radius: 6px;
            margin-top: 20px;
            font-size: 14px;
        }
        .steps {
            text-align: left;
            margin: 20px 0;
            padding: 0 20px;
        }
        .steps li {
            margin: 8px 0;
            color: #555;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>light point</h1>
        </div>
        <div class="content">
            <h2>You've Been Invited to Join!</h2>
            <p>Hello,</p>
            <p><strong>{{.InviterName}}</strong> has invited you to join light point as a <strong>{{.Role}}</strong>.</p>

            <div class="role-badge">{{.Role}}</div>

            <p>Your email address: <strong>{{.InviteeEmail}}</strong></p>

            <p>Click the button below to set your password and activate your account:</p>
            <p style="text-align: center;">
                <a href="{{.InvitationURL}}" class="button">Set Your Password</a>
            </p>

            <p>Or copy and paste this link into your browser:</p>
            <p class="link-text">{{.InvitationURL}}</p>

            <div class="info-box">
                <strong>What happens next?</strong>
                <ul class="steps">
                    <li>Click the button above to set your password</li>
                    <li>Once your password is set, you can log in with your email and new password</li>
                </ul>
                <p style="margin-bottom: 0;"><strong>Note:</strong> This invitation expires in {{.ExpiryDays}} days.</p>
            </div>
        </div>
        <div class="footer">
            <p>&copy; light point. All rights reserved.</p>
            <p>This is an automated message, please do not reply.</p>
            <p style="color: #999; font-size: 11px;">If you did not expect this invitation, you can safely ignore this email.</p>
        </div>
    </div>
</body>
</html>`

	textTmpl := `light point - Admin Invitation

Hello,

{{.InviterName}} has invited you to join light point as a {{.Role}}.

Your email address: {{.InviteeEmail}}

To set your password and activate your account, click the link below:

{{.InvitationURL}}

What happens next?
1. Click the link above to set your password
2. Once your password is set, you can log in with your email and new password

This invitation expires in {{.ExpiryDays}} days.

---
light point
This is an automated message, please do not reply.

If you did not expect this invitation, you can safely ignore this email.`

	var htmlBuf, textBuf bytes.Buffer

	htmlTemplate, err := template.New("html").Parse(htmlTmpl)
	if err != nil {
		return "", "", err
	}
	if err = htmlTemplate.Execute(&htmlBuf, data); err != nil {
		return "", "", err
	}

	textTemplate, err := template.New("text").Parse(textTmpl)
	if err != nil {
		return "", "", err
	}
	if err = textTemplate.Execute(&textBuf, data); err != nil {
		return "", "", err
	}

	return htmlBuf.String(), textBuf.String(), nil
}

// GenerateTeamInvitationEmail generates HTML and text versions of team invitation email
func (t *EmailTemplates) GenerateTeamInvitationEmail(data TeamInvitationEmailData) (html, text string, err error) {
	htmlTmpl := `<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            line-height: 1.6;
            color: #333;
            margin: 0;
            padding: 0;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px 20px;
            text-align: center;
            border-radius: 8px 8px 0 0;
        }
        .header h1 {
            margin: 0;
            font-size: 28px;
            font-weight: 600;
        }
        .content {
            padding: 30px;
            background-color: #ffffff;
            border-radius: 0 0 8px 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .content h2 {
            color: #333;
            margin-top: 0;
        }
        .team-card {
            background: linear-gradient(135deg, #667eea15 0%, #764ba215 100%);
            border: 1px solid #667eea30;
            border-radius: 12px;
            padding: 20px;
            margin: 20px 0;
            text-align: center;
        }
        .team-name {
            font-size: 24px;
            font-weight: bold;
            color: #667eea;
            margin: 0 0 8px 0;
        }
        .inviter-info {
            color: #666;
            font-size: 14px;
        }
        .button {
            display: inline-block;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white !important;
            padding: 14px 32px;
            text-decoration: none;
            border-radius: 8px;
            margin: 20px 0;
            font-weight: 600;
            font-size: 16px;
        }
        .button:hover {
            opacity: 0.9;
        }
        .link-text {
            word-break: break-all;
            color: #666;
            font-size: 14px;
            background-color: #f9f9f9;
            padding: 10px;
            border-radius: 4px;
            margin: 10px 0;
        }
        .footer {
            padding: 20px;
            text-align: center;
            color: #666;
            font-size: 12px;
        }
        .info-box {
            background-color: #E8F4FD;
            border: 1px solid #B3D9F7;
            padding: 12px;
            border-radius: 6px;
            margin-top: 20px;
            font-size: 14px;
        }
        .steps {
            text-align: left;
            margin: 20px 0;
            padding: 0 20px;
        }
        .steps li {
            margin: 8px 0;
            color: #555;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>light point</h1>
        </div>
        <div class="content">
            <h2>You've Been Invited!</h2>
            <p>Hello,</p>
            <p><strong>{{.InviterName}}</strong> has invited you to join their team on light point:</p>

            <div class="team-card">
                <p class="team-name">{{.TeamName}}</p>
                <p class="inviter-info">Invited by {{.InviterName}}</p>
            </div>

            <p>To accept this invitation and join the team, click the button below:</p>
            <p style="text-align: center;">
                <a href="{{.InvitationURL}}" class="button">Accept Invitation</a>
            </p>

            <p>Or copy and paste this link into your browser:</p>
            <p class="link-text">{{.InvitationURL}}</p>

            <div class="info-box">
                <strong>What happens next?</strong>
                <ul class="steps">
                    <li>Click the button above to accept the invitation</li>
                    <li>If you don't have an account, you'll be guided to create one</li>
                    <li>Once registered, you'll automatically join the team</li>
                </ul>
                <p style="margin-bottom: 0;"><strong>Note:</strong> This invitation expires in {{.ExpiryDays}} days.</p>
            </div>
        </div>
        <div class="footer">
            <p>&copy; light point. All rights reserved.</p>
            <p>This is an automated message, please do not reply.</p>
            <p style="color: #999; font-size: 11px;">If you did not expect this invitation, you can safely ignore this email.</p>
        </div>
    </div>
</body>
</html>`

	textTmpl := `light point - Team Invitation

Hello,

{{.InviterName}} has invited you to join their team "{{.TeamName}}" on light point!

To accept this invitation, click the link below:

{{.InvitationURL}}

What happens next?
1. Click the link above to accept the invitation
2. If you don't have an account, you'll be guided to create one
3. Once registered, you'll automatically join the team

This invitation expires in {{.ExpiryDays}} days.

---
light point
This is an automated message, please do not reply.

If you did not expect this invitation, you can safely ignore this email.`

	var htmlBuf, textBuf bytes.Buffer

	htmlTemplate, err := template.New("html").Parse(htmlTmpl)
	if err != nil {
		return "", "", err
	}
	if err = htmlTemplate.Execute(&htmlBuf, data); err != nil {
		return "", "", err
	}

	textTemplate, err := template.New("text").Parse(textTmpl)
	if err != nil {
		return "", "", err
	}
	if err = textTemplate.Execute(&textBuf, data); err != nil {
		return "", "", err
	}

	return htmlBuf.String(), textBuf.String(), nil
}
