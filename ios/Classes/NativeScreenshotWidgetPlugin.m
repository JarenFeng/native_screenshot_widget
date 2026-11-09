#import "NativeScreenshotWidgetPlugin.h"

@interface NativeScreenshotWidgetPlugin ()
- (nullable UIWindow *)screenshotWindow;
@end

@implementation NativeScreenshotWidgetPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    NativeScreenshotWidgetPlugin* instance = [[NativeScreenshotWidgetPlugin alloc] init];
    ScreenshotHostApiSetup(registrar.messenger, instance);
}

- (nullable UIWindow *)screenshotWindow {
    UIApplication *application = UIApplication.sharedApplication;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in application.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (window.isKeyWindow && !window.hidden && window.rootViewController != nil) {
                    return window;
                }
            }
        }
        // Only legacy applications keep their window on the application delegate.
        if (application.connectedScenes.count > 0) return nil;
    }
    if (application.applicationState != UIApplicationStateActive) return nil;
    if ([application.delegate respondsToSelector:@selector(window)]) {
        UIWindow *window = application.delegate.window;
        if (!window.hidden && window.isKeyWindow) return window;
    }
    return nil;
}

- (void)takeScreenshotWithCompletion:(nonnull void (^)(FlutterStandardTypedData * _Nullable, FlutterError * _Nullable))completion {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self takeScreenshotWithCompletion:completion];
        });
        return;
    }

    @try {
        UIWindow *window = [self screenshotWindow];
        UIView *view = window.rootViewController.view;
        if (window == nil || view.window != window || CGRectIsEmpty(view.bounds)) {
            completion(nil, [FlutterError errorWithCode:@"TakeScreenshotError"
                                               message:@"No visible view is available for screenshot."
                                               details:nil]);
            return;
        }

        UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
        format.scale = window.screen.scale;
        format.opaque = view.opaque;
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithBounds:view.bounds format:format];
        __block BOOL didDraw = NO;
        UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
            didDraw = [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];
        }];
        NSData *imageData = didDraw ? UIImageJPEGRepresentation(image, 1.0f) : nil;
        if (imageData.length == 0) {
            completion(nil, [FlutterError errorWithCode:@"TakeScreenshotError"
                                               message:@"Failed to render or encode screenshot."
                                               details:nil]);
            return;
        }
        completion([FlutterStandardTypedData typedDataWithBytes:imageData], nil);
    } @catch (NSException *exception) {
        completion(nil, [FlutterError errorWithCode:@"TakeScreenshotError"
                                           message:@"Failed to take screenshot."
                                           details:exception.description]);
    }
}

@end
