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
    var activityPluginBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        flutterApi =
            LinkOsMultiplatformSdkFlutterApi(binding.binaryMessenger)
        hostApi =
            LinkOsMultiplatformSdkHostApiImpl(
                context = binding.applicationContext,
                flutterApi = flutterApi
            )

        LinkOsMultiplatformSdkHostApi.setUp(
            binding.binaryMessenger,
            hostApi
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        hostApi.activity = binding.activity
        activityPluginBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        hostApi.activity = null
        activityPluginBinding?.removeRequestPermissionsResultListener(this)
        activityPluginBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        hostApi.activity = binding.activity
        activityPluginBinding = binding
        binding.addRequestPermissionsResultListener(this);
    }

    override fun onDetachedFromActivity() {
        hostApi.activity = null
        activityPluginBinding?.removeRequestPermissionsResultListener(this)
        activityPluginBinding = null
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
