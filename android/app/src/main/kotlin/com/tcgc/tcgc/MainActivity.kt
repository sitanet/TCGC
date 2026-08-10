package com.tcgc.tcgc

import android.os.Bundle
import androidx.core.view.WindowCompat
import com.ryanheise.audioservice.AudioServiceFragmentActivity

class MainActivity : AudioServiceFragmentActivity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Enable edge-to-edge display on all Android versions
        // This makes the system navigation bar transparent so our app
        // draws behind it, preventing overlap with the bottom nav bar
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }
}
