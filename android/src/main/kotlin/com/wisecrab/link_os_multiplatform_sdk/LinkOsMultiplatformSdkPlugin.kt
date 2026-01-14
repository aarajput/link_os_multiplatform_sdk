package com.wisecrab.link_os_multiplatform_sdk

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

class LinkOsMultiplatformSdkPlugin :
    FlutterPlugin {
    private lateinit var channel: MethodChannel
    private lateinit var linkOsMultiplatformSdkFlutterApi: LinkOsMultiplatformSdkFlutterApi
    private lateinit var linkOsMultiplatformSdkHostApi: LinkOsMultiplatformSdkHostApiImpl
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        linkOsMultiplatformSdkFlutterApi =
            LinkOsMultiplatformSdkFlutterApi(flutterPluginBinding.binaryMessenger)
        linkOsMultiplatformSdkHostApi =
            LinkOsMultiplatformSdkHostApiImpl(
                context = flutterPluginBinding.applicationContext,
                flutterApi = linkOsMultiplatformSdkFlutterApi
            )

        LinkOsMultiplatformSdkHostApi.setUp(
            flutterPluginBinding.binaryMessenger,
            linkOsMultiplatformSdkHostApi
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
