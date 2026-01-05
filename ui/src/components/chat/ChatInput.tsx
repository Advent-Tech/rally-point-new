import React, { useState, useRef } from 'react';
import {
  View,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  Platform,
  KeyboardAvoidingView,
} from 'react-native';
import Icon from '../Icon';

interface ChatInputProps {
  onSendMessage: (message: string) => void;
  onTyping?: (isTyping: boolean) => void;
  placeholder?: string;
  disabled?: boolean;
}

const ChatInput: React.FC<ChatInputProps> = ({
  onSendMessage,
  onTyping,
  placeholder = 'Type a message...',
  disabled = false,
}) => {
  const [message, setMessage] = useState('');
  const [isTyping, setIsTyping] = useState(false);
  const inputRef = useRef<TextInput>(null);
  const typingTimeoutRef = useRef<NodeJS.Timeout>();

  const handleTextChange = (text: string) => {
    setMessage(text);
    
    // Handle typing indicator
    if (onTyping) {
      if (!isTyping && text.length > 0) {
        setIsTyping(true);
        onTyping(true);
      }
      
      // Clear existing timeout
      if (typingTimeoutRef.current) {
        clearTimeout(typingTimeoutRef.current);
      }
      
      // Set new timeout to stop typing indicator
      typingTimeoutRef.current = setTimeout(() => {
        setIsTyping(false);
        onTyping(false);
      }, 1000);
    }
  };

  const handleSend = () => {
    if (message.trim() && !disabled) {
      onSendMessage(message.trim());
      setMessage('');
      
      // Stop typing indicator
      if (isTyping && onTyping) {
        setIsTyping(false);
        onTyping(false);
      }
      
      // Clear timeout
      if (typingTimeoutRef.current) {
        clearTimeout(typingTimeoutRef.current);
      }
    }
  };

  const canSend = message.trim().length > 0 && !disabled;

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      style={styles.container}
    >
      <View style={styles.inputContainer}>
        <View style={styles.inputWrapper}>
          <TextInput
            ref={inputRef}
            style={styles.textInput}
            value={message}
            onChangeText={handleTextChange}
            placeholder={placeholder}
            placeholderTextColor="#999"
            multiline
            maxLength={1000}
            editable={!disabled}
            returnKeyType="send"
            onSubmitEditing={handleSend}
            blurOnSubmit={false}
          />
          
          <TouchableOpacity
            style={styles.attachButton}
            onPress={() => {
              // Handle attachment functionality
              console.log('Attach file');
            }}
            disabled={disabled}
          >
            <Icon name="attach" size={20} color="#666" />
          </TouchableOpacity>
        </View>
        
        <TouchableOpacity
          style={[
            styles.sendButton,
            canSend ? styles.sendButtonActive : styles.sendButtonInactive
          ]}
          onPress={handleSend}
          disabled={!canSend}
        >
          <Icon 
            name="send" 
            size={20} 
            color={canSend ? '#FFFFFF' : '#999'} 
          />
        </TouchableOpacity>
      </View>
    </KeyboardAvoidingView>
  );
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: '#FFFFFF',
    borderTopWidth: 1,
    borderTopColor: '#E5E5E5',
  },
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    paddingHorizontal: 16,
    paddingVertical: 12,
    minHeight: 60,
  },
  inputWrapper: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'flex-end',
    backgroundColor: '#F5F5F5',
    borderRadius: 25,
    paddingHorizontal: 16,
    paddingVertical: 8,
    marginRight: 12,
    minHeight: 40,
  },
  textInput: {
    flex: 1,
    fontSize: 16,
    lineHeight: 20,
    maxHeight: 100,
    color: '#000',
    paddingVertical: 8,
  },
  attachButton: {
    padding: 4,
    marginLeft: 8,
  },
  sendButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
    elevation: 2,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.2,
    shadowRadius: 2,
  },
  sendButtonActive: {
    backgroundColor: '#007AFF',
  },
  sendButtonInactive: {
    backgroundColor: '#E5E5E5',
  },
});

export default ChatInput;
