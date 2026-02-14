allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ Esto es CLAVE: manda los builds Android a ../build (raíz del proyecto)
rootProject.buildDir = file("../build")

subprojects {
    buildDir = file("${rootProject.buildDir}/${project.name}")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
