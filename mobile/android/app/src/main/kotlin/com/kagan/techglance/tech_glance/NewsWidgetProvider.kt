package com.kagan.techglance.tech_glance

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import android.content.Intent
import android.widget.RemoteViewsService
import android.util.Log
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import org.json.JSONArray
import org.json.JSONObject
import java.util.ArrayList

class NewsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                // Initialize the service to populate the list view
                val intent = Intent(context, NewsWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
                }
                setRemoteAdapter(R.id.widget_list_view, intent)
                setEmptyView(R.id.widget_list_view, R.id.empty_view)

                // Open the app when the header is clicked
                val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.header_container, pendingIntent)
            }
            
            // Notify the widget manager to update the data
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list_view)
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class NewsWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return NewsRemoteViewsFactory(this.applicationContext)
    }
}

class NewsRemoteViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var newsList = ArrayList<JSONObject>()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        newsList.clear()
        Log.d("TechGlanceWidget", "Refeshing widget data...")

        try {
            // STRATEGY: Read directly from Flutter's SharedPreferences file.
            // Flutter adds a "flutter." prefix to all keys.
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val jsonString = prefs.getString("flutter.cached_news", "[]")
            
            if (jsonString != null && jsonString != "null" && jsonString != "[]") {
                val jsonArray = JSONArray(jsonString)
                for (i in 0 until jsonArray.length()) {
                    newsList.add(jsonArray.getJSONObject(i))
                }
                Log.d("TechGlanceWidget", "Loaded ${newsList.size} articles.")
            } else {
                Log.d("TechGlanceWidget", "No data found in SharedPreferences.")
            }
        } catch (e: Exception) {
            Log.e("TechGlanceWidget", "Error reading data: ${e.message}")
            e.printStackTrace()
        }
    }

    override fun onDestroy() { newsList.clear() }
    override fun getCount(): Int = newsList.size
    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_item)
        try {
            val item = newsList[position]
            views.setTextViewText(R.id.news_source, item.optString("source"))
            views.setTextViewText(R.id.news_time, item.optString("time"))
            views.setTextViewText(R.id.news_summary, item.optString("summary"))
            
            // Intent to open the URL (Flutter handles the deep link logic if needed, or browser opens)
            val fillInIntent = Intent().apply {
                val url = item.optString("link")
                data = Uri.parse(url)
            }
            views.setOnClickFillInIntent(R.id.news_summary, fillInIntent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return views
    }
}