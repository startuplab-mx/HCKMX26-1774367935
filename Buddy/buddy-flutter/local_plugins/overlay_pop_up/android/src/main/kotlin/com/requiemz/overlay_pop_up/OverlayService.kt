package com.requiemz.overlay_pop_up

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.View
import android.view.Gravity
import android.view.WindowManager
import android.view.WindowManager.LayoutParams
import android.widget.FrameLayout
import android.widget.ImageView
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.JSONMessageCodec
import kotlin.math.sqrt

class OverlayService : Service(), BasicMessageChannel.MessageHandler<Any?>, View.OnTouchListener {
    companion object {
        var isActive: Boolean = false
        var windowManager: WindowManager? = null
        var flutterView: FlutterView? = null
        var lastX = 0f
        var lastY = 0f

        private const val NOTIFICATION_ID = 9876
        private const val CHANNEL_ID = "overlay_pop_up_foreground_service"
        private const val CHANNEL_NAME = "Overlay Service"
    }

    private lateinit var overlayMessageChannel: BasicMessageChannel<Any?>

    // Drop zone (trash icon) variables
    private var dropZoneView: FrameLayout? = null
    private var trashIconView: ImageView? = null
    private var isDragging = false
    private var isDismissing = false
    private var isInDropZone = false
    private var isDropZoneVisible = false // Track if drop zone is currently visible
    private var initialTouchX = 0f // Initial touch position for drag detection
    private var initialTouchY = 0f
    private var totalDragDistance = 0f // Accumulated drag distance
    private val DROP_ZONE_SIZE = 200 // Size of the drop zone circle in pixels
    private val DROP_ZONE_THRESHOLD = 150 // Distance threshold to trigger drop zone
    private val DRAG_ACTIVATION_THRESHOLD = 30f // Minimum drag distance (in pixels) to show drop zone
    private var targetScale = 0.3f // Scale to fit inside drop zone

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    @SuppressLint("ClickableViewAccessibility")
    override fun onCreate() {
        super.onCreate()

        // Start foreground service immediately on Android O+ to comply with background service restrictions
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            println("[OverlayPopUp] Starting foreground service with notification (Android ${Build.VERSION.SDK_INT})")
            try {
                startForeground(NOTIFICATION_ID, createNotification())
                println("[OverlayPopUp] Foreground service started successfully")
            } catch (e: Exception) {
                println("[OverlayPopUp] ERROR starting foreground service: ${e.message}")
                e.printStackTrace()
            }
        }

        PopUp.loadPreferences(applicationContext)
        val engine = FlutterEngineCache.getInstance().get(OverlayPopUpPlugin.CACHE_ENGINE_ID)
        if (engine == null) {
            println("[OverlayPopUp] FlutterEngine not available in cache. Stopping service.")
            stopSelf()
            return
        }
        engine.lifecycleChannel.appIsResumed()

        // Create FlutterTextureView first and let it initialize
        val textureView = FlutterTextureView(applicationContext)

        flutterView = object : FlutterView(applicationContext, textureView) {
            override fun dispatchKeyEvent(event: KeyEvent): Boolean {
                return if (event.keyCode == KeyEvent.KEYCODE_BACK && PopUp.closeWhenTapBackButton) {
                    // Only remove view if it's still attached to window manager
                    flutterView?.let { view ->
                        try {
                            if (view.isAttachedToWindow) {
                                windowManager?.removeView(view)
                            }
                        } catch (e: IllegalArgumentException) {
                            println("[OverlayPopUp] View already removed on back button: ${e.message}")
                        }
                    }
                    stopService(Intent(baseContext, OverlayService::class.java))
                    isActive = false
                    true
                } else super.dispatchKeyEvent(event)
            }
        }

        // Attach to engine first, before adding to window
        flutterView?.attachToFlutterEngine(engine)
        // false: el FlutterView no aplica padding por status bar / cutout. Lo
        // necesitamos así porque FLAG_LAYOUT_NO_LIMITS + LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
        // ya colocan la window sobre el notch; con fitsSystemWindows=true el
        // contenido se empuja hacia abajo y el sprite sale del notch.
        flutterView?.fitsSystemWindows = false
        flutterView?.setBackgroundColor(Color.TRANSPARENT)
        flutterView?.setOnTouchListener(this)

        // Set up message channel handler for overlay → main app communication
        overlayMessageChannel = BasicMessageChannel(
            engine.dartExecutor,
            OverlayPopUpPlugin.OVERLAY_TO_MAIN_CHANNEL_NAME,
            JSONMessageCodec.INSTANCE
        )
        overlayMessageChannel.setMessageHandler(this)

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager?
        val windowConfig = WindowManager.LayoutParams(
            PopUp.width,
            PopUp.height,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
            if (PopUp.backgroundBehavior == 1) WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN else
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            PixelFormat.TRANSPARENT
        )
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O_MR1) {
            windowConfig.flags = windowConfig.flags or WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        }
        windowConfig.gravity = PopUp.verticalAlignment or PopUp.horizontalAlignment
        windowConfig.screenOrientation = PopUp.screenOrientation
        windowConfig.x = PopUp.offsetX
        windowConfig.y = PopUp.offsetY
        // Allow rendering inside the camera/notch area and over the status bar
        windowConfig.flags = windowConfig.flags or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            windowConfig.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
        }

        // Add view to window - InputChannel will be initialized by Flutter framework
        try {
            // Create drop zone (trash icon) FIRST if swipeToDismiss is enabled
            // This ensures the overlay (added after) will be on top of the drop zone
            if (PopUp.swipeToDismiss) {
                createDropZone()
            }

            // Add overlay view AFTER drop zone so it appears on top
            windowManager?.addView(flutterView, windowConfig)
            loadLastPosition()

            isActive = true
        } catch (e: Exception) {
            println("[OverlayPopUp] Error adding view to window: ${e.message}")
            e.printStackTrace()
            stopSelf()
        }
    }

    override fun onDestroy() {
        super.onDestroy()

        // Only remove views if they are still attached to window manager
        // This prevents crash when animateDismiss already removed them
        flutterView?.let { view ->
            try {
                if (view.isAttachedToWindow) {
                    windowManager?.removeView(view)
                }
            } catch (e: IllegalArgumentException) {
                println("[OverlayPopUp] FlutterView already removed in onDestroy: ${e.message}")
            }
        }
        dropZoneView?.let { view ->
            try {
                if (view.isAttachedToWindow) {
                    windowManager?.removeView(view)
                }
            } catch (e: IllegalArgumentException) {
                println("[OverlayPopUp] DropZoneView already removed in onDestroy: ${e.message}")
            }
        }
        isActive = false
    }

    override fun onMessage(message: Any?, reply: BasicMessageChannel.Reply<Any?>) {
        // Send message from overlay to main app using dedicated channel
        val mainAppMessenger = OverlayPopUpPlugin.mainAppMessenger
        if (mainAppMessenger != null) {
            val overlayToMainChannel = BasicMessageChannel(
                mainAppMessenger,
                OverlayPopUpPlugin.OVERLAY_TO_MAIN_CHANNEL_NAME,
                JSONMessageCodec.INSTANCE
            )
            overlayToMainChannel.send(message) { result ->
                reply.reply(result)
            }
        } else {
            println("[OverlayService] ERROR: Main app messenger not available!")
            reply.reply(null)
        }
    }

    override fun onTouch(v: View?, event: MotionEvent?): Boolean {
        if (!PopUp.isDraggable && !PopUp.swipeToDismiss) return false
        if (isDismissing) return true

        val view = flutterView ?: return false
        val windowConfig = view.layoutParams as? LayoutParams ?: return false

        when (event?.action) {
            MotionEvent.ACTION_DOWN -> {
                lastX = event.rawX
                lastY = event.rawY
                initialTouchX = event.rawX
                initialTouchY = event.rawY
                isDragging = true
                totalDragDistance = 0f
                // Don't show drop zone yet - wait for actual dragging
            }
            MotionEvent.ACTION_MOVE -> {
                val dx = event.rawX - lastX
                val dy = event.rawY - lastY
                if (dx * dx + dy * dy < 25) {
                    return false
                }

                // Free dragging in all directions
                if (PopUp.isDraggable || PopUp.swipeToDismiss) {
                    lastX = event.rawX
                    lastY = event.rawY
                    val finalX = windowConfig.x + dx.toInt()
                    val finalY = windowConfig.y + dy.toInt()
                    windowConfig.x = finalX
                    windowConfig.y = finalY
                    windowManager?.updateViewLayout(view, windowConfig)

                    if (PopUp.isDraggable) {
                        saveLastPosition(finalX, finalY)
                    }

                    // Calculate total drag distance from initial touch
                    if (PopUp.swipeToDismiss && !isDropZoneVisible) {
                        val dragDx = event.rawX - initialTouchX
                        val dragDy = event.rawY - initialTouchY
                        totalDragDistance = sqrt((dragDx * dragDx + dragDy * dragDy).toDouble()).toFloat()

                        // Show drop zone only after dragging past threshold
                        if (totalDragDistance >= DRAG_ACTIVATION_THRESHOLD) {
                            showDropZone()
                            isDropZoneVisible = true
                        }
                    }

                    // Check if overlay is in drop zone (only if drop zone is visible)
                    if (PopUp.swipeToDismiss && isDropZoneVisible) {
                        checkDropZoneCollision(event.rawX, event.rawY)
                    }
                }
            }

            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                isDragging = false
                totalDragDistance = 0f

                // Check if released in drop zone BEFORE hiding (to avoid resetting the flag)
                val shouldDismiss = PopUp.swipeToDismiss && isInDropZone

                // Hide drop zone if it was shown
                if (PopUp.swipeToDismiss && isDropZoneVisible) {
                    hideDropZone()
                    isDropZoneVisible = false

                    if (shouldDismiss) {
                        animateDismiss(windowConfig)
                    } else {
                    }
                }
                return false
            }

            else -> return false
        }
        return false
    }

    private fun createDropZone() {
        dropZoneView = FrameLayout(applicationContext)
        trashIconView = ImageView(applicationContext)

        // Configure close icon
        trashIconView?.apply {
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            setColorFilter(Color.WHITE)
            val iconSize = (DROP_ZONE_SIZE * 0.5).toInt()
            layoutParams = FrameLayout.LayoutParams(
                iconSize,
                iconSize,
                Gravity.CENTER
            )
        }

        // Configure drop zone container with circular shape
        dropZoneView?.apply {
            addView(trashIconView)
            // Create circular background
            background = createCircularDrawable()
            alpha = 0f // Start invisible
            elevation = 10f
        }

        // Add drop zone to window (bottom center)
        val dropZoneParams = WindowManager.LayoutParams(
            DROP_ZONE_SIZE,
            DROP_ZONE_SIZE,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        )
        dropZoneParams.gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
        dropZoneParams.y = 100 // 100px from bottom

        windowManager?.addView(dropZoneView, dropZoneParams)

        // Calculate target scale to fit overlay inside drop zone
        calculateTargetScale()
    }

    private fun calculateTargetScale() {
        // Get overlay dimensions
        val overlayWidth = PopUp.width.toFloat()
        val overlayHeight = PopUp.height.toFloat()

        // Calculate the maximum dimension of the overlay
        val maxOverlayDimension = maxOf(overlayWidth, overlayHeight)

        // Calculate scale needed to fit inside drop zone (with some padding)
        val availableSpace = DROP_ZONE_SIZE * 0.7f // Use 70% of drop zone to leave some margin
        targetScale = if (maxOverlayDimension > 0) {
            (availableSpace / maxOverlayDimension).coerceIn(0.1f, 1f)
        } else {
            0.3f // Default fallback
        }
    }

    private fun createCircularDrawable(): android.graphics.drawable.GradientDrawable {
        return android.graphics.drawable.GradientDrawable().apply {
            shape = android.graphics.drawable.GradientDrawable.OVAL
            setColor(Color.parseColor("#CCFF0000"))
            setStroke(8, Color.parseColor("#FFFF0000"))
        }
    }

    private fun showDropZone() {
        dropZoneView?.animate()
            ?.alpha(1f)
            ?.scaleX(1f)
            ?.scaleY(1f)
            ?.setDuration(200)
            ?.start()
    }

    private fun hideDropZone() {
        dropZoneView?.animate()
            ?.alpha(0f)
            ?.setDuration(200)
            ?.start()
        isInDropZone = false
    }

    private fun checkDropZoneCollision(touchX: Float, touchY: Float) {
        val dropZoneParams = dropZoneView?.layoutParams as? WindowManager.LayoutParams ?: return
        val view = flutterView ?: return

        // Get screen dimensions
        val displayMetrics = resources.displayMetrics
        val screenWidth = displayMetrics.widthPixels
        val screenHeight = displayMetrics.heightPixels

        // Calculate overlay center position (not touch position)
        val windowConfig = view.layoutParams as LayoutParams
        val overlayWidth = (PopUp.width * view.scaleX).toInt()
        val overlayHeight = (PopUp.height * view.scaleY).toInt()

        // Calculate overlay center in screen coordinates
        val overlayCenterX = when (windowConfig.gravity and Gravity.HORIZONTAL_GRAVITY_MASK) {
            Gravity.LEFT -> windowConfig.x + overlayWidth / 2f
            Gravity.RIGHT -> screenWidth - windowConfig.x - overlayWidth / 2f
            else -> screenWidth / 2f + windowConfig.x
        }

        val overlayCenterY = when (windowConfig.gravity and Gravity.VERTICAL_GRAVITY_MASK) {
            Gravity.TOP -> windowConfig.y + overlayHeight / 2f
            Gravity.BOTTOM -> screenHeight - windowConfig.y - overlayHeight / 2f
            else -> screenHeight / 2f + windowConfig.y
        }

        // Calculate drop zone center position
        val dropZoneCenterX = screenWidth / 2f
        val dropZoneCenterY = screenHeight - 100f - (DROP_ZONE_SIZE / 2f)

        // Calculate distance between overlay center and drop zone center
        val distance = sqrt(
            ((overlayCenterX - dropZoneCenterX) * (overlayCenterX - dropZoneCenterX) +
            (overlayCenterY - dropZoneCenterY) * (overlayCenterY - dropZoneCenterY)).toDouble()
        ).toFloat()

        val wasInDropZone = isInDropZone
        isInDropZone = distance < DROP_ZONE_THRESHOLD

        // Animate overlay shrinking when entering drop zone
        if (isInDropZone && !wasInDropZone) {
            // Just entered the zone
            animateOverlayShrink(true)
            animateDropZonePulse()
        } else if (!isInDropZone && wasInDropZone) {
            // Just left the zone
            animateOverlayShrink(false)
        } else if (isInDropZone) {
            // Still inside the zone - make sure it stays small
            // This handles cases where animation might have been interrupted
            if (view.scaleX > targetScale + 0.05f) {
                view.scaleX = targetScale
                view.scaleY = targetScale
            }
        }
    }

    private fun animateOverlayShrink(shrink: Boolean) {
        val scale = if (shrink) targetScale else 1f
        flutterView?.animate()
            ?.scaleX(scale)
            ?.scaleY(scale)
            ?.setDuration(200)
            ?.start()
    }

    private fun animateDropZonePulse() {
        dropZoneView?.animate()
            ?.scaleX(1.2f)
            ?.scaleY(1.2f)
            ?.setDuration(150)
            ?.withEndAction {
                dropZoneView?.animate()
                    ?.scaleX(1f)
                    ?.scaleY(1f)
                    ?.setDuration(150)
                    ?.start()
            }
            ?.start()
    }

    private fun animateDismiss(windowConfig: LayoutParams) {
        isDismissing = true

        // Animate overlay shrinking and fading out
        flutterView?.animate()
            ?.scaleX(0f)
            ?.scaleY(0f)
            ?.alpha(0f)
            ?.setDuration(300)
            ?.withEndAction {
                // Close the overlay - only remove views if they are still attached to window manager
                // This prevents crash when views were already removed
                flutterView?.let { view ->
                    try {
                        if (view.isAttachedToWindow) {
                            windowManager?.removeView(view)
                        }
                    } catch (e: IllegalArgumentException) {
                        println("[OverlayPopUp] FlutterView already removed from window: ${e.message}")
                    }
                }
                dropZoneView?.let { view ->
                    try {
                        if (view.isAttachedToWindow) {
                            windowManager?.removeView(view)
                        }
                    } catch (e: IllegalArgumentException) {
                        println("[OverlayPopUp] DropZoneView already removed from window: ${e.message}")
                    }
                }
                stopService(Intent(baseContext, OverlayService::class.java))
                isActive = false
                isDismissing = false
            }
            ?.start()
    }

    private fun saveLastPosition(x: Int, y: Int) {
        PopUp.lastX = x
        PopUp.lastY = y
        PopUp.savePreferences(applicationContext)
    }

    private fun loadLastPosition() {
        if (PopUp.lastY == 0 && PopUp.lastX == 0) return
        flutterView?.let { view ->
            val windowConfig = view.layoutParams as LayoutParams
            windowConfig.x = PopUp.lastX
            windowConfig.y = PopUp.lastY
            windowManager?.updateViewLayout(view, windowConfig)
        }
    }

    private fun createNotification(): android.app.Notification {
        // Create notification channel for Android O+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(NotificationManager::class.java)

            // Check if channel already exists, if not create it
            var channel = notificationManager?.getNotificationChannel(CHANNEL_ID)
            if (channel == null) {
                channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Foreground service for overlay functionality"
                    setShowBadge(false)
                    lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                }
                notificationManager?.createNotificationChannel(channel)
                println("[OverlayPopUp] Notification channel created: $CHANNEL_ID")
            }
        }

        // Get notification icon from the resource name passed from Dart
        val appIcon = try {
            if (PopUp.notificationIcon.isEmpty()) {
                println("[OverlayPopUp] ERROR: notificationIcon is required but was not provided!")
                println("[OverlayPopUp] Please pass notificationIcon parameter to showOverlay()")
                android.R.drawable.ic_dialog_info
            } else {
                val packageName = applicationContext.packageName
                val resources = applicationContext.resources

                // Try to find the icon in drawable first
                var iconResId = resources.getIdentifier(PopUp.notificationIcon, "drawable", packageName)

                // If not found in drawable, try mipmap
                if (iconResId == 0) {
                    iconResId = resources.getIdentifier(PopUp.notificationIcon, "mipmap", packageName)
                }

                if (iconResId != 0) {
                    println("[OverlayPopUp] Using notification icon '${PopUp.notificationIcon}' with resource ID: $iconResId")
                    iconResId
                } else {
                    println("[OverlayPopUp] WARNING: Icon '${PopUp.notificationIcon}' not found in drawable or mipmap")
                    println("[OverlayPopUp] Make sure the icon exists in your app's resources")
                    android.R.drawable.ic_dialog_info
                }
            }
        } catch (e: Exception) {
            println("[OverlayPopUp] Failed to get notification icon: ${e.message}")
            e.printStackTrace()
            android.R.drawable.ic_dialog_info
        }

        // Build notification with customizable text
        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(PopUp.notificationTitle)
            .setSmallIcon(appIcon)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .setShowWhen(false)
            .setAutoCancel(false)

        // Only set content text if it's not empty
        if (PopUp.notificationText.isNotEmpty()) {
            notificationBuilder.setContentText(PopUp.notificationText)
        }

        val notification = notificationBuilder.build()

        println("[OverlayPopUp] Notification created with title: ${PopUp.notificationTitle}")
        return notification
    }
}
