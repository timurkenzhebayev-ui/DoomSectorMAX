package com.timur.onetapflashlight;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.graphics.PixelFormat;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.WindowManager;
import android.widget.Toast;

public class MainActivity extends Activity {
    private CameraManager cameraManager;
    private String torchCameraId;
    private CameraManager.TorchCallback torchCallback;
    private boolean actionHandled;
    private final Handler handler = new Handler(Looper.getMainLooper());

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        makeWindowInvisible();
        toggleTorch();
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        actionHandled = false;
        toggleTorch();
    }

    private void makeWindowInvisible() {
        WindowManager.LayoutParams p = getWindow().getAttributes();
        p.width = 1;
        p.height = 1;
        p.gravity = Gravity.TOP | Gravity.START;
        p.dimAmount = 0f;
        p.format = PixelFormat.TRANSLUCENT;
        getWindow().setAttributes(p);
        getWindow().addFlags(
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE |
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE |
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL);
    }

    private void toggleTorch() {
        cleanupCallback();
        actionHandled = false;
        cameraManager = (CameraManager) getSystemService(Context.CAMERA_SERVICE);

        try {
            torchCameraId = findBackFlashCamera(cameraManager);
            if (torchCameraId == null) {
                Toast.makeText(this, "Фонарик не найден", Toast.LENGTH_SHORT).show();
                finishAndRemoveTask();
                return;
            }
        } catch (CameraAccessException e) {
            Toast.makeText(this, "Камера временно недоступна", Toast.LENGTH_SHORT).show();
            finishAndRemoveTask();
            return;
        }

        torchCallback = new CameraManager.TorchCallback() {
            @Override
            public void onTorchModeChanged(String cameraId, boolean enabled) {
                if (!cameraId.equals(torchCameraId) || actionHandled) return;
                actionHandled = true;
                cleanupCallback();
                boolean turnOn = !enabled;
                try {
                    cameraManager.setTorchMode(torchCameraId, turnOn);
                    if (turnOn) {
                        // Keep this process cached so Android keeps ownership of the torch,
                        // but immediately return the user to whatever was on screen before.
                        handler.postDelayed(() -> moveTaskToBack(true), 80);
                    } else {
                        handler.postDelayed(MainActivity.this::finishAndRemoveTask, 80);
                    }
                } catch (CameraAccessException | IllegalArgumentException | SecurityException e) {
                    Toast.makeText(MainActivity.this, "Не удалось переключить фонарик", Toast.LENGTH_SHORT).show();
                    finishAndRemoveTask();
                }
            }

            @Override
            public void onTorchModeUnavailable(String cameraId) {
                if (cameraId.equals(torchCameraId) && !actionHandled) {
                    actionHandled = true;
                    cleanupCallback();
                    Toast.makeText(MainActivity.this, "Фонарик сейчас занят камерой", Toast.LENGTH_SHORT).show();
                    finishAndRemoveTask();
                }
            }
        };

        cameraManager.registerTorchCallback(getMainExecutor(), torchCallback);

        handler.postDelayed(() -> {
            if (!actionHandled) {
                actionHandled = true;
                cleanupCallback();
                Toast.makeText(MainActivity.this, "Не удалось определить состояние фонарика", Toast.LENGTH_SHORT).show();
                finishAndRemoveTask();
            }
        }, 1800);
    }

    private String findBackFlashCamera(CameraManager manager) throws CameraAccessException {
        String anyFlash = null;
        for (String id : manager.getCameraIdList()) {
            CameraCharacteristics c = manager.getCameraCharacteristics(id);
            Boolean hasFlash = c.get(CameraCharacteristics.FLASH_INFO_AVAILABLE);
            if (!Boolean.TRUE.equals(hasFlash)) continue;
            if (anyFlash == null) anyFlash = id;
            Integer facing = c.get(CameraCharacteristics.LENS_FACING);
            if (facing != null && facing == CameraCharacteristics.LENS_FACING_BACK) {
                return id;
            }
        }
        return anyFlash;
    }

    private void cleanupCallback() {
        if (cameraManager != null && torchCallback != null) {
            try {
                cameraManager.unregisterTorchCallback(torchCallback);
            } catch (Exception ignored) {
            }
            torchCallback = null;
        }
    }
}
