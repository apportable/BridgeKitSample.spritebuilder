package com.apportable.bridgekitsample;

import android.widget.Toast;
import android.app.Activity;
import android.util.Log;

public class ToastBridge {
    private Activity activity;
    public int toastCount = 0;
    private static int totalToastCount = 0;
    
    public ToastBridge(Activity activity) {
        this.activity = activity;
        toastCount = totalToastCount;
    }

    public void showToast(final String text) {
        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                Log.d("ToastBridge.java", "This is a debug message in Java!");
                Toast toast = Toast.makeText(activity, text, Toast.LENGTH_SHORT);
                toast.show();
                toastCount = totalToastCount++;
                
                callbackFromJava("Hey, Objective-C! What's up?");                
            }
        });
    }
    
    private native void callbackFromJava(String message);
}