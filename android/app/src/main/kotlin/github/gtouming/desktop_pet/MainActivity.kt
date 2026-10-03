package github.gtouming.desktop_pet

import com.desktop_pet.multi_floating_window.MultiFloatingWindowAndroidPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private val plugin: MultiFloatingWindowAndroidPlugin by lazy { MultiFloatingWindowAndroidPlugin() }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 手动注册多悬浮窗插件
        flutterEngine.plugins.add(plugin)
    }
}
