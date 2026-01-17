import Flutter
import UIKit

public class LinkOsMultiplatformSdkPlugin: NSObject, FlutterPlugin {

  public static func register(with registrar: FlutterPluginRegistrar) {
    let flutterApi = LinkOsMultiplatformSdkFlutterApi(
      binaryMessenger: registrar.messenger(),
    )
    let hostApi = LinkOsMultiplatformSdkHostApiImpl(
      flutterApi: flutterApi,
    )
    LinkOsMultiplatformSdkHostApiSetup.setUp(
      binaryMessenger: registrar.messenger(),
      api: hostApi,
    )
  }
}
