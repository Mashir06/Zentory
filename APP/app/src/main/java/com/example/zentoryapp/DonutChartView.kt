package com.example.zentoryapp

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View

class DonutChartView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }

    private var data = mutableListOf<Pair<String, Float>>()
    private var colors = mutableMapOf<String, Int>()
    private val rect = RectF()
    private var donutStrokeWidth = 40f

    fun setData(newData: Map<String, Int>, categoryColors: Map<String, Int>) {
        val total = newData.values.sum().toFloat()
        data.clear()
        if (total > 0) {
            newData.forEach { (cat, count) ->
                if (count > 0) {
                    data.add(cat to (count / total) * 360f)
                }
            }
        }
        colors.clear()
        colors.putAll(categoryColors)
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val padding = 20f
        val size = Math.min(width, height).toFloat() - padding * 2
        donutStrokeWidth = size * 0.15f
        paint.strokeWidth = donutStrokeWidth

        val left = (width - size) / 2
        val top = (height - size) / 2
        val right = left + size
        val bottom = top + size

        rect.set(left + donutStrokeWidth/2, top + donutStrokeWidth/2, right - donutStrokeWidth/2, bottom - donutStrokeWidth/2)

        if (data.isEmpty()) {
            paint.color = Color.parseColor("#334155") // Color de fondo si no hay datos
            canvas.drawArc(rect, 0f, 360f, false, paint)
            return
        }

        var startAngle = -90f
        data.forEach { (cat, angle) ->
            paint.color = colors[cat] ?: Color.GRAY
            // Dibujamos el arco. Si es casi 360, dibujamos 360.
            val sweepAngle = if (angle >= 360f) 360f else angle
            canvas.drawArc(rect, startAngle, sweepAngle, false, paint)
            startAngle += angle
        }
    }
}
