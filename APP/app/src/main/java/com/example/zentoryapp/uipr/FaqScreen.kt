package com.example.zentoryapp.uipr

import android.view.LayoutInflater
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import androidx.navigation.NavController
import com.example.zentoryapp.databinding.FaqActivityBinding

@Composable
fun FaqScreen(navController: NavController) {
    AndroidView(
        modifier = Modifier.fillMaxSize(),
        factory = { context ->
            val b = FaqActivityBinding.inflate(LayoutInflater.from(context))

            b.btnBack.setOnClickListener {
                navController.popBackStack()
            }

            b.root
        }
    )
}
