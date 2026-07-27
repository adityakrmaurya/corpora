// Root build file. Applies Java 25 toolchain + Google-style Checkstyle to every service
// module as they're added under subprojects. See config/checkstyle/checkstyle.xml
// (Checkstyle's official google_checks.xml, fetched verbatim from checkstyle/checkstyle)
// and config/formatter/eclipse-java-google-style.xml (Google's official Eclipse formatter
// profile, wired into Zed/JDTLS via lsp.jdtls in this repo's own .zed/settings.json — not
// a personal editor config — so format-on-save matches this file's Checkstyle gate for
// every contributor, not just whoever set it up first).

subprojects {
    apply(plugin = "java")
    apply(plugin = "checkstyle")

    configure<JavaPluginExtension> {
        toolchain {
            languageVersion.set(JavaLanguageVersion.of(25))
        }
    }

    configure<CheckstyleExtension> {
        toolVersion = "10.20.2"
        configFile = rootProject.file("config/checkstyle/checkstyle.xml")
        isIgnoreFailures = false
        maxWarnings = 0
    }

    tasks.withType<Checkstyle>().configureEach {
        reports {
            xml.required.set(true)
            html.required.set(true)
        }
    }
}
