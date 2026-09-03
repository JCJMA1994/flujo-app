// ignore_for_file: avoid_print, leading_newlines_in_multiline_strings, prefer_const_declarations
import 'dart:io';

void main() {
  final baseDir = Directory(
    r'D:\.pub_cache\hosted\pub.dev\notification_listener_service-0.3.5\android\src\main\java\notification\listener\service',
  );

  if (!baseDir.existsSync()) {
    print('Base directory not found: ${baseDir.path}');
    return;
  }

  patchPlugin(baseDir);
  patchReceiver(baseDir);
  patchListener(baseDir);
}

void patchPlugin(Directory baseDir) {
  final file = File('${baseDir.path}/NotificationListenerServicePlugin.java');
  if (!file.existsSync()) return;

  final code = '''package notification.listener.service;

import static notification.listener.service.NotificationUtils.isPermissionGranted;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;
import android.content.ActivityNotFoundException;
import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import notification.listener.service.models.Action;
import notification.listener.service.models.ActionCache;

import java.util.List;
import java.util.Map;

public class NotificationListenerServicePlugin implements FlutterPlugin, ActivityAware, MethodCallHandler, PluginRegistry.ActivityResultListener, EventChannel.StreamHandler {

    private static final String CHANNEL_TAG = "x-slayer/notifications_channel";
    private static final String EVENT_TAG = "x-slayer/notifications_event";

    private MethodChannel channel;
    private EventChannel eventChannel;
    private NotificationReceiver notificationReceiver;
    private Context context;
    private Activity mActivity;

    private Result pendingResult;
    final int REQUEST_CODE_FOR_NOTIFICATIONS = 1199;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        context = flutterPluginBinding.getApplicationContext();
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), CHANNEL_TAG);
        channel.setMethodCallHandler(this);
        eventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), EVENT_TAG);
        eventChannel.setStreamHandler(this);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        if (call.method.equals("isPermissionGranted")) {
            result.success(isPermissionGranted(context));
        } else if (call.method.equals("requestPermission")) {
            pendingResult = result;
            Intent intent = new Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS);
            try {
                if (mActivity != null) {
                    mActivity.startActivityForResult(intent, REQUEST_CODE_FOR_NOTIFICATIONS);
                } else {
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    context.startActivity(intent);
                    result.success(isPermissionGranted(context));
                    pendingResult = null;
                }
            } catch (ActivityNotFoundException e) {
                Log.e("NotificationPlugin", "ActivityNotFoundException: " + e.getMessage());
                result.error("ACTIVITY_NOT_FOUND", "No activity found to handle notification listener settings", null);
                pendingResult = null;
            }
        } else if (call.method.equals("sendReply")) {
            final String message = call.argument("message");
            final int notificationId = call.argument("notificationId");

            final Action action = ActionCache.cachedNotifications.get(notificationId);
            if (action == null) {
                result.error("Notification", "Can't find this cached notification", null);
                return;
            }
            try {
                action.sendReply(context, message);
                result.success(true);
            } catch (PendingIntent.CanceledException e) {
                result.success(false);
                e.printStackTrace();
            }
        } else if (call.method.equals("getActiveNotifications")) {
            NotificationListener service = NotificationListener.getInstance();
            if (service != null) {
                List<Map<String, Object>> notifications = service.getActiveNotificationData();
                result.success(notifications);
            } else {
                result.error("ServiceUnavailable", "NotificationService not running", null);
            }
        }
        else {
            result.notImplemented();
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        eventChannel.setStreamHandler(null);
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        this.mActivity = binding.getActivity();
        binding.addActivityResultListener(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        onAttachedToActivity(binding);
    }

    @Override
    public void onDetachedFromActivity() {
        this.mActivity = null;
    }

    @SuppressLint("WrongConstant")
    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        try {
            IntentFilter intentFilter = new IntentFilter();
            intentFilter.addAction(NotificationConstants.INTENT);
            notificationReceiver = new NotificationReceiver(events);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                context.registerReceiver(notificationReceiver, intentFilter, Context.RECEIVER_EXPORTED);
            } else {
                context.registerReceiver(notificationReceiver, intentFilter);
            }
            Log.i("NotificationPlugin", "Started the notifications tracking service.");
        } catch (Throwable t) {
            Log.e("NotificationPlugin", "Error starting notification listener in onListen", t);
        }
    }

    @Override
    public void onCancel(Object arguments) {
        if (notificationReceiver != null) {
            try {
                context.unregisterReceiver(notificationReceiver);
            } catch (Throwable ignored) {}
            notificationReceiver = null;
        }
    }

    @Override
    public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == REQUEST_CODE_FOR_NOTIFICATIONS) {
            if (pendingResult != null) {
                try {
                    boolean granted = isPermissionGranted(context);
                    pendingResult.success(granted);
                } catch (Throwable t) {
                    Log.w("NotificationPlugin", "Safe catch in onActivityResult duplicate reply: " + t.getMessage());
                } finally {
                    pendingResult = null;
                }
            }
            return true;
        }
        return false;
    }
}
''';

  file.writeAsStringSync(code);
  print('Patched NotificationListenerServicePlugin.java with double-reply crash prevention.');
}

void patchReceiver(Directory baseDir) {
  final file = File('${baseDir.path}/NotificationReceiver.java');
  if (!file.existsSync()) return;

  final code = '''package notification.listener.service;

import static notification.listener.service.NotificationConstants.*;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build.VERSION_CODES;
import android.util.Log;

import androidx.annotation.RequiresApi;

import io.flutter.plugin.common.EventChannel.EventSink;

import java.util.HashMap;

public class NotificationReceiver extends BroadcastReceiver {

    private static EventSink staticEventSink;
    private EventSink eventSink;

    public NotificationReceiver() {
        this.eventSink = staticEventSink;
    }

    public NotificationReceiver(EventSink eventSink) {
        this.eventSink = eventSink;
        staticEventSink = eventSink;
    }

    @RequiresApi(api = VERSION_CODES.JELLY_BEAN_MR2)
    @Override
    public void onReceive(Context context, Intent intent) {
        try {
            EventSink sink = eventSink != null ? eventSink : staticEventSink;
            if (sink == null || intent == null) return;

            String packageName = intent.getStringExtra(PACKAGE_NAME);
            String title = intent.getStringExtra(NOTIFICATION_TITLE);
            String content = intent.getStringExtra(NOTIFICATION_CONTENT);
            byte[] notificationIcon = intent.getByteArrayExtra(NOTIFICATIONS_ICON);
            byte[] notificationExtrasPicture = intent.getByteArrayExtra(EXTRAS_PICTURE);
            byte[] largeIcon = intent.getByteArrayExtra(NOTIFICATIONS_LARGE_ICON);
            boolean haveExtraPicture = intent.getBooleanExtra(HAVE_EXTRA_PICTURE, false);
            boolean hasRemoved = intent.getBooleanExtra(IS_REMOVED, false);
            boolean canReply = intent.getBooleanExtra(CAN_REPLY, false);
            boolean isOngoing = intent.getBooleanExtra(IS_ONGOING, false);
            int id = intent.getIntExtra(ID, -1);

            HashMap<String, Object> data = new HashMap<>();
            data.put("id", id);
            data.put("packageName", packageName);
            data.put("title", title);
            data.put("content", content);
            data.put("notificationIcon", notificationIcon);
            data.put("notificationExtrasPicture", notificationExtrasPicture);
            data.put("haveExtraPicture", haveExtraPicture);
            data.put("largeIcon", largeIcon);
            data.put("hasRemoved", hasRemoved);
            data.put("canReply", canReply);
            data.put("onGoing", isOngoing);

            sink.success(data);
        } catch (Throwable t) {
            Log.e("NotificationReceiver", "Safe catch onReceive: " + t.getMessage(), t);
        }
    }
}
''';

  file.writeAsStringSync(code);
  print('Patched NotificationReceiver.java with default constructor and safe execution.');
}

void patchListener(Directory baseDir) {
  final file = File('${baseDir.path}/NotificationListener.java');
  if (!file.existsSync()) return;

  final code = '''package notification.listener.service;

import static notification.listener.service.NotificationUtils.getBitmapFromDrawable;
import static notification.listener.service.models.ActionCache.cachedNotifications;

import android.annotation.SuppressLint;
import android.app.Notification;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.Icon;
import android.os.Build;
import android.os.Build.VERSION_CODES;
import android.os.Bundle;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.util.Log;
import java.util.List;
import java.util.Map;
import java.util.ArrayList;
import java.util.HashMap;

import androidx.annotation.RequiresApi;

import java.io.ByteArrayOutputStream;

import notification.listener.service.models.Action;

@SuppressLint("OverrideAbstract")
@RequiresApi(api = VERSION_CODES.JELLY_BEAN_MR2)
public class NotificationListener extends NotificationListenerService {
    private static NotificationListener instance;

    public static NotificationListener getInstance() {
        return instance;
    }

    @Override
    public void onListenerConnected() {
        try {
            super.onListenerConnected();
            instance = this;
            Log.i("NotificationListener", "NotificationListener connected successfully");
        } catch (Throwable t) {
            Log.e("NotificationListener", "Safe catch in onListenerConnected", t);
        }
    }

    @RequiresApi(api = VERSION_CODES.KITKAT)
    @Override
    public void onNotificationPosted(StatusBarNotification notification) {
        try {
            handleNotification(notification, false);
        } catch (Throwable t) {
            Log.e("NotificationListener", "Safe catch in onNotificationPosted", t);
        }
    }

    @RequiresApi(api = VERSION_CODES.KITKAT)
    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        try {
            handleNotification(sbn, true);
        } catch (Throwable t) {
            Log.e("NotificationListener", "Safe catch in onNotificationRemoved", t);
        }
    }

    @RequiresApi(api = VERSION_CODES.KITKAT)
    private void handleNotification(StatusBarNotification notification, boolean isRemoved) {
        if (notification == null || notification.getNotification() == null) return;

        try {
            String packageName = notification.getPackageName();
            Bundle extras = notification.getNotification().extras;
            boolean isOngoing = (notification.getNotification().flags & Notification.FLAG_ONGOING_EVENT) != 0;

            Action action = null;
            try {
                action = NotificationUtils.getQuickReplyAction(notification.getNotification(), packageName);
            } catch (Throwable ignored) {}

            Intent intent = new Intent(NotificationConstants.INTENT);
            intent.setPackage(getPackageName());
            intent.putExtra(NotificationConstants.PACKAGE_NAME, packageName);
            intent.putExtra(NotificationConstants.ID, notification.getId());
            intent.putExtra(NotificationConstants.CAN_REPLY, action != null);
            intent.putExtra(NotificationConstants.IS_ONGOING, isOngoing);

            if (action != null) {
                cachedNotifications.put(notification.getId(), action);
            }

            if (extras != null) {
                try {
                    CharSequence title = extras.getCharSequence(Notification.EXTRA_TITLE);
                    CharSequence text = extras.getCharSequence(Notification.EXTRA_TEXT);
                    intent.putExtra(NotificationConstants.NOTIFICATION_TITLE, title == null ? null : title.toString());
                    intent.putExtra(NotificationConstants.NOTIFICATION_CONTENT, text == null ? null : text.toString());
                } catch (Throwable ignored) {}
                intent.putExtra(NotificationConstants.IS_REMOVED, isRemoved);
            }

            sendBroadcast(intent);
        } catch (Throwable t) {
            Log.e("NotificationListener", "Error in handleNotification safely caught: " + t.getMessage(), t);
        }
    }

    @RequiresApi(api = Build.VERSION_CODES.KITKAT)
    public List<Map<String, Object>> getActiveNotificationData() {
        List<Map<String, Object>> notificationList = new ArrayList<>();
        try {
            StatusBarNotification[] activeNotifications = getActiveNotifications();
            if (activeNotifications == null) return notificationList;

            for (StatusBarNotification sbn : activeNotifications) {
                if (sbn == null || sbn.getNotification() == null) continue;
                Map<String, Object> notifData = new HashMap<>();
                Notification notification = sbn.getNotification();
                Bundle extras = notification.extras;

                notifData.put("id", sbn.getId());
                notifData.put("packageName", sbn.getPackageName());
                if (extras != null) {
                    notifData.put("title", extras.getCharSequence(Notification.EXTRA_TITLE) != null
                            ? extras.getCharSequence(Notification.EXTRA_TITLE).toString()
                            : null);
                    notifData.put("content", extras.getCharSequence(Notification.EXTRA_TEXT) != null
                            ? extras.getCharSequence(Notification.EXTRA_TEXT).toString()
                            : null);
                }
                boolean isOngoing = (notification.flags & Notification.FLAG_ONGOING_EVENT) != 0;
                notifData.put("onGoing", isOngoing);

                notificationList.add(notifData);
            }
        } catch (Throwable t) {
            Log.e("NotificationListener", "Safe catch getActiveNotificationData", t);
        }
        return notificationList;
    }
}
''';

  file.writeAsStringSync(code);
  print('Patched NotificationListener.java with try-catch and memory leak / crash prevention.');
}
