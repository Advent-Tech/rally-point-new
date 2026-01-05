import React, { useEffect, useRef } from 'react';
import { Platform } from 'react-native';

/**
 * WebScrollFix Component
 * Fixes scrolling issues on web by injecting necessary CSS overrides
 * Only applies to web platform to avoid mobile interference
 */
const WebScrollFix: React.FC = () => {
  const hasInjected = useRef(false);

  useEffect(() => {
    // Only run on web platform
    if (Platform.OS !== 'web') {
      return;
    }

    // Only run once
    if (hasInjected.current) {
      return;
    }
    hasInjected.current = true;
    
    // Remove any existing style first
    const existingStyle = document.getElementById('rally-point-web-scroll-fix');
    if (existingStyle) {
      existingStyle.remove();
    }

    // Create and inject CSS styles for web scrolling fix
    const style = document.createElement('style');
    style.id = 'rally-point-web-scroll-fix';
    
    style.textContent = `
      /* Rally Point Web Scroll Fix - WEB ONLY */
      html, body {
        height: 100%;
        margin: 0;
        padding: 0;
        overflow-x: hidden;
      }

      /* Override the default overflow: hidden from Expo on web only */
      body {
        overflow: visible !important;
        overflow-y: auto !important;
        overflow-x: hidden !important;
      }

      /* Ensure root container allows scrolling on web */
      #root {
        height: 100vh !important;
        width: 100vw !important;
        overflow: visible !important;
        display: flex !important;
        flex: 1 !important;
      }

      /* Fix ONLY problematic nested flex containers - preserve ScrollView functionality */
      [style*="flex: 1"]:not(.rn-scrollview):not([class*="scroll"]):not([class*="Scroll"]) {
        min-height: 0 !important;
        min-width: 0 !important;
      }

      /* Ensure ScrollView works properly on web */
      .rn-scrollview {
        overflow: auto !important;
        -webkit-overflow-scrolling: touch !important;
        height: auto !important;
        max-height: none !important;
        flex: 1 !important;
      }

      /* Don't apply min-height fixes to ScrollView children */
      .rn-scrollview [style*="flex: 1"], .rn-scrollview [style*="flex:1"] {
        height: auto !important;
        min-height: auto !important;
      }

      /* Ensure proper scrolling for content containers */
      [class*="scroll"], [class*="Scroll"] {
        -webkit-overflow-scrolling: touch !important;
        overflow-y: auto !important;
        overflow-x: hidden !important;
        min-height: auto !important;
      }

      /* Scrollbar styling for better UX on web */
      ::-webkit-scrollbar {
        width: 8px;
      }

      ::-webkit-scrollbar-track {
        background: #f1f1f1;
        border-radius: 4px;
      }

      ::-webkit-scrollbar-thumb {
        background: #c1c1c1;
        border-radius: 4px;
      }

      ::-webkit-scrollbar-thumb:hover {
        background: #a8a8a8;
      }

      /* Ensure smooth scrolling on web */
      * {
        scroll-behavior: smooth !important;
      }

      /* Web responsiveness */
      @media (max-width: 768px) and (min-width: 769px) {
        body {
          overflow-x: hidden !important;
        }
        
        #root {
          overflow-x: hidden !important;
        }
      }

      /* Fix for React Native Web View components - exclude scrollable elements */
      div[style*="display: flex"]:not(.rn-scrollview):not([class*="scroll"]):not([class*="Scroll"]) {
        min-height: 0 !important;
        min-width: 0 !important;
      }

      /* Prevent content overflow on web */
      * {
        box-sizing: border-box !important;
      }
    `;
    
    document.head.appendChild(style);
    console.log('✅ Web scroll fix CSS injected for web platform only - ScrollView preserved');

    // Cleanup function
    return () => {
      if (Platform.OS === 'web' && hasInjected.current) {
        const existingStyle = document.getElementById('rally-point-web-scroll-fix');
        if (existingStyle) {
          existingStyle.remove();
          hasInjected.current = false;
        }
      }
    };
  }, []); // Empty dependency array ensures this runs only once

  // This component doesn't render anything
  return null;
};

export default WebScrollFix;
