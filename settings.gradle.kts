import org.gradle.api.initialization.resolve.RepositoriesMode

rootProject.name = "corpora"

dependencyResolutionManagement {
    // Centralized, single source of truth for repositories — every subproject (and the
    // checkstyle plugin's own tool dependency, com.puppycrawl.tools:checkstyle) resolves
    // from here. FAIL_ON_PROJECT_REPOS prevents a subproject from silently declaring its
    // own repositories{} block and drifting from this list.
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        mavenCentral()
    }
}

// Service modules are added here as they're scaffolded (see docs/architecture/c4-container.md
// for the full 14-service list and docs/adr/0012-database-per-service-postgres-instances.md /
// 0014-single-language-java-stack.md for why this is one multi-module Gradle build).
