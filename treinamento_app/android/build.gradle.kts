import com.android.build.gradle.BaseExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Alguns plugins (ex: tflite_flutter) não fixam a JVM target do Kotlin no
// próprio build.gradle, deixando o Gradle inferir o valor a partir do JDK
// instalado na máquina (que pode ser um Java bem mais novo). Isso entra em
// conflito com a compilação Java do mesmo plugin, que por padrão usa Java
// 1.8, e o Gradle recusa a build ("Inconsistent JVM Target Compatibility
// Between Java and Kotlin Tasks"). Forçamos aqui, para TODOS os
// subprojetos (o app e cada plugin), o mesmo alvo (17) usado no restante
// do projeto.
//
// Importante: configuramos isso através da EXTENSÃO `android.compileOptions`
// (a mesma API que os próprios plugins usam), e não diretamente nas tasks
// `JavaCompile` — o AGP recalcula e reaplica `sourceCompatibility` /
// `targetCompatibility` nas tasks a partir dessa extensão em um momento
// posterior da configuração, então sobrescrever a task diretamente é
// sobrescrito de volta pelo AGP; mexer na extensão é o que "gruda" de fato.
//
// Pelo mesmo motivo, também forçamos aqui o `compileSdkVersion` de todos os
// subprojetos para 36: o `tflite_flutter` está fixado em `android-31` no
// próprio pacote, enquanto dependências transitivas de outros plugins (ex:
// androidx.fragment via o `camera`) exigem compileSdk 33/34+. Sem isso, o
// AGP recusa a build com "AAR metadata check" (dependência X requer
// compilar contra a API Y ou mais recente).
subprojects {
    afterEvaluate {
        extensions.findByType(BaseExtension::class.java)?.apply {
            compileSdkVersion(36)
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
        tasks.withType<KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(JvmTarget.JVM_17)
        }
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
