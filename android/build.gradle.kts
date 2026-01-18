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
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Fix for AGP 8+ requiring namespace in libraries that don't have it
subprojects {
    // Define the logic in a closure or function
    val configureNamespace = {
        val android = project.extensions.findByName("android")
        if (android != null) {
            try {
                val getNamespace = android.javaClass.getMethod("getNamespace")
                val currentNamespace = getNamespace.invoke(android) as? String

                if (currentNamespace == null) {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    var groupName = project.group.toString()
                    // If group is not set, generate a fake one to satisfy AGP
                    if (groupName.isEmpty() || groupName == "null" || groupName == "unspecified") {
                         // Sanitizing the project name for valid package usage
                        val safeName = project.name.replace("-", "_").replace(Regex("[^a-zA-Z0-9_]"), "")
                        groupName = "com.example.$safeName"
                    }
                    setNamespace.invoke(android, groupName)
                    println("Auto-injected namespace '$groupName' for project '${project.name}'")
                }
            } catch (e: Exception) {
                println("Failed to inject namespace for ${project.name}: $e")
            }
        }
    }

    // Apply immediately if already evaluated, otherwise defer
    if (project.state.executed) {
        configureNamespace()
    } else {
        project.afterEvaluate {
            configureNamespace()
        }
    }
}
