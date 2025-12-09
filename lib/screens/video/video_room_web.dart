// Web-only implementation for Jitsi Meet
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:js' as js;

class VideoRoomWeb {
  static void registerViewFactory(String viewId, String roomId, String userName, String userEmail) {
    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) {
        final container = html.DivElement()
          ..id = viewId.toString()
          ..style.width = '100%'
          ..style.height = '100%';
        
        // Sử dụng Jitsi Meet External API với retry logic
        final viewIdStr = viewId.toString();
        js.context.callMethod('eval', ['''
          (function initJitsi() {
            const container = document.getElementById('$viewIdStr');
            if (!container) {
              setTimeout(initJitsi, 100);
              return;
            }
            
            if (typeof JitsiMeetExternalAPI !== 'undefined') {
              const domain = 'meet.jit.si';
              const options = {
                roomName: '$roomId',
                parentNode: container,
                width: '100%',
                height: '100%',
                configOverwrite: {
                  prejoinPageEnabled: false,
                  startWithAudioMuted: false,
                  startWithVideoMuted: false,
                  requireDisplayName: false,
                  enableWelcomePage: false,
                  enableNoAudioDetection: false,
                  enableNoisyMicDetection: false,
                  enableLayerSuspension: true,
                  enableInsecureRoomNameWarning: false,
                  disableDeepLinking: true,
                  enableClosePage: false,
                  defaultLanguage: 'vi',
                  enableLobbyChat: false,
                  enableKnockingLobby: false,
                  enablePrejoinPage: false,
                  enableTalkWhileMuted: false,
                  enableRemb: true,
                  enableTcc: true,
                  useStunTurn: true,
                  p2p: {
                    enabled: true,
                    stunServers: [
                      { urls: 'stun:meet.jit.si:443' }
                    ]
                  }
                },
                interfaceConfigOverwrite: {
                  TOOLBAR_BUTTONS: [
                    'microphone', 'camera', 'closedcaptions', 'desktop', 'fullscreen',
                    'fodeviceselection', 'hangup', 'chat', 'settings', 'raisehand',
                    'videoquality', 'filmstrip', 'invite', 'feedback', 'stats', 'shortcuts',
                    'tileview', 'videobackgroundblur', 'download', 'help', 'mute-everyone', 'security'
                  ],
                  SETTINGS_SECTIONS: ['devices', 'language', 'moderator', 'profile', 'calendar'],
                  SHOW_JITSI_WATERMARK: false,
                  SHOW_WATERMARK_FOR_GUESTS: false,
                  SHOW_BRAND_WATERMARK: false,
                  BRAND_WATERMARK_LINK: '',
                  SHOW_POWERED_BY: false,
                  DISPLAY_WELCOME_PAGE_CONTENT: false,
                  DISPLAY_WELCOME_PAGE_TOOLBAR_ADDITIONAL_CONTENT: false,
                  APP_NAME: 'Gia sư và Học sinh',
                  NATIVE_APP_NAME: 'Gia sư và Học sinh',
                  PROVIDER_NAME: 'Gia sư và Học sinh'
                },
                userInfo: {
                  displayName: '${userName.replaceAll("'", "\\'")}',
                  email: '${userEmail.replaceAll("'", "\\'")}'
                }
              };
              
              const api = new JitsiMeetExternalAPI(domain, options);
              
              // Tự động join và set làm moderator
              api.addEventListener('videoConferenceJoined', function() {
                console.log('Joined conference');
              });
              
              api.addEventListener('participantRoleChanged', function(event) {
                console.log('Role changed:', event);
              });
              
              // Lưu API instance để có thể control sau này
              window.jitsiAPI = api;
            } else {
              console.log('Waiting for JitsiMeetExternalAPI...');
              container.innerHTML = '<div style="display: flex; align-items: center; justify-content: center; height: 100%; color: white; background: #1a1a1a;"><p>Đang tải Jitsi Meet...</p></div>';
              setTimeout(initJitsi, 500);
            }
          })();
        ''']);
        
        return container;
      },
    );
  }
  
  static void dispose() {
    try {
      js.context.callMethod('eval', ['''
        if (window.jitsiAPI) {
          window.jitsiAPI.dispose();
          window.jitsiAPI = null;
        }
      ''']);
    } catch (e) {
      print('Error disposing Jitsi API: $e');
    }
  }
}

