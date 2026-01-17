allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")

    // Workaround for missing namespace in AGP 8+ (e.g. background_sms)
    plugins.withId("com.android.library") {
        val extension = extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
        if (extension != null && extension.namespace == null) {
            extension.namespace = project.group.toString().takeIf { it.isNotEmpty() && it != "null" } 
                ?: "com.example.${project.name.replace("-", "_")}"
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
