allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // Force a resolvable protobuf version — iris_method_channel pins AGP 7.1.2
    // which requests protobuf-java:3.10.0, a version no longer on Maven Central.
    configurations.all {
        resolutionStrategy.eachDependency {
            if (requested.group == "com.google.protobuf" && requested.name == "protobuf-java") {
                useVersion("3.21.12")
                because("protobuf-java 3.10.0 is unavailable on Maven Central")
            }
            if (requested.group == "com.google.protobuf" && requested.name == "protobuf-java-util") {
                useVersion("3.21.12")
                because("protobuf-java-util 3.10.0 is unavailable on Maven Central")
            }
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
