package com.wisecrab.link_os_multiplatform_sdk

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class LinkOsMultiplatformSdkPlugin :
    FlutterPlugin, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
    private lateinit var channel: MethodChannel
    private lateinit var flutterApi: LinkOsMultiplatformSdkFlutterApi
    private lateinit var hostApi: LinkOsMultiplatformSdkHostApiImpl
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        flutterApi =
            LinkOsMultiplatformSdkFlutterApi(flutterPluginBinding.binaryMessenger)
        hostApi =
            LinkOsMultiplatformSdkHostApiImpl(
                context = flutterPluginBinding.applicationContext,
                flutterApi = flutterApi
            )

        LinkOsMultiplatformSdkHostApi.setUp(
            flutterPluginBinding.binaryMessenger,
            hostApi
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        hostApi.activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        hostApi.activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        hostApi.activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        hostApi.activity = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String?>,
        grantResults: IntArray
    ): Boolean {
        return hostApi.onRequestPermissionsResult(
            requestCode = requestCode,
            permissions = permissions,
            grantResults = grantResults
        )
    }
}
