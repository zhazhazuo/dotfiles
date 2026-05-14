# Heuristics

## Detect Backend

### Node.js
IF:
- express / fastify / koa in deps
THEN:
- generate api_index.md
- add HTTP layer to system_map

### Python
IF:
- fastapi / flask / django in requirements.txt or pyproject.toml
THEN:
- generate api_index.md
- note Python runtime in tech_stack

### Go
IF:
- gin / echo / fiber in go.mod
THEN:
- generate api_index.md
- note Go runtime in tech_stack

### Java
IF:
- spring-boot / spring-web in pom.xml or build.gradle
THEN:
- generate api_index.md
- note Java/JVM runtime in tech_stack

### Rust
IF:
- `Cargo.toml` exists
- actix-web / axum / warp / rocket in dependencies
THEN:
- generate api_index.md (if HTTP crate detected)
- note Rust runtime in tech_stack

### Ruby
IF:
- `Gemfile` exists
- rails / sinatra / hanami in Gemfile
THEN:
- generate api_index.md
- note Ruby runtime in tech_stack

### PHP
IF:
- `composer.json` exists
- laravel / symfony / slim in require section
THEN:
- generate api_index.md
- note PHP runtime in tech_stack

### .NET / C#
IF:
- `*.csproj` or `*.sln` exists
- Microsoft.AspNetCore in csproj dependencies
THEN:
- generate api_index.md
- note .NET runtime in tech_stack

### Elixir
IF:
- `mix.exs` exists
- phoenix / plug in deps
THEN:
- generate api_index.md
- note Elixir/OTP runtime in tech_stack

---

## Detect Frontend

### Frontend Framework
IF:
- react / next / gatsby in deps → note React (or Next.js / Gatsby)
- vue / nuxt in deps → note Vue (or Nuxt)
- angular in deps → note Angular
- svelte / sveltekit in deps → note Svelte (or SvelteKit)
- uni-app / @dcloudio/uni-app in deps → note UniApp
- flutter (pubspec.yaml exists) → note Flutter
- taro / @tarojs/taro in deps → note Taro
THEN:
- include UI layer in system_map
- create components module in 04_modules/
- record detected framework name in tech_stack

### Style Framework
IF:
- less in devDeps → note Less
- sass / node-sass / dart-sass in devDeps → note Sass/SCSS
- postcss-modules or *.module.css convention in config → note CSS Modules
- tailwindcss in devDeps → note Tailwind CSS
- styled-components / emotion in deps → note CSS-in-JS (styled-components / Emotion)
- unocss in devDeps → note UnoCSS
THEN:
- record detected style framework in tech_stack

### UI Framework
IF:
- element-plus / element-ui in deps → note Element Plus / Element UI
- ant-design-vue / antd in deps → note Ant Design (Vue / React)
- vant in deps → note Vant
- naive-ui in deps → note Naive UI
- arco-design / @arco-design in deps → note Arco Design
- @mui/material in deps → note MUI (Material UI)
- vuetify in deps → note Vuetify
- @nutui/nutui in deps → note NutUI
- tdesign-vue-next / tdesign-react in deps → note TDesign
THEN:
- record detected UI framework in tech_stack

---

## Detect Database

IF:
- postgres / mysql / sqlite / sequelize / prisma / typeorm in deps
THEN:
- add DB layer to system_map

IF:
- mongodb / mongoose in deps
THEN:
- add DB layer to system_map (document store)

IF:
- redis / ioredis in deps
THEN:
- add Cache layer to system_map

---

## Detect Real-time

IF:
- websocket / socket.io / ws in deps
THEN:
- create websocket module
- add Realtime layer to system_map

---

## Detect CI/CD

IF:
- `.github/workflows/*.yml` exists
THEN:
- note GitHub Actions in tech_stack
- add CI pipeline to deploy.md

IF:
- `.gitlab-ci.yml` exists
THEN:
- note GitLab CI in tech_stack

IF:
- `Makefile` exists
THEN:
- extract targets for guides

---

## Detect Infrastructure

IF:
- `docker-compose.yml` exists
THEN:
- note Docker Compose in tech_stack
- add services to system_map

IF:
- `k8s/` or `kubernetes/` directory exists
THEN:
- note Kubernetes in tech_stack

IF:
- `terraform/` directory exists
THEN:
- note Terraform in tech_stack

---

## Detect Monorepo

IF:
- multiple `package.json` at different directory levels
THEN:
- treat each package as sub-module
- create separate 04_modules/ entry per package
