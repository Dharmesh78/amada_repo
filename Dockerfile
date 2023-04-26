#
# Dockerfile - React npm ビルド ＆ Java Maven ビルド
#
# 説明：
#    Dockerイメージを作るための手順を記述したファイル
#
#    OCI DevOps プロジェクト の ビルド・パイプライン で指定された
#    「ビルド仕様ファイル・パス: build_spec.yaml」をもとに
#    プロジェクトに含まれたbuild_spec.yamlファイルが参照され、docker build コマンドを発行します。
#    docker build は プロジェクトに含まれた このDockerfile を参照してアプリケーションビルドを行ないます。 
# 
# 処理概要：
#  【１-１】Maven ビルドを実行し、リモートリポジトリ(Nexus)にデプロイまで行なう。
#  【１-２】Tomcatコンテナイメージにビルドしたアプリケーションを配置する。
#  【１-３】Tomcatを起動するコマンドを追加する。
#

# >>> フロント npmインストール＆ビルド

FROM nrt.ocir.io/nrjlf5npv1v1/node:14.21.3 AS builder-react

WORKDIR /tmp

COPY ./pom.xml .
#COPY ./settings.xml .
#COPY ./application.properties .
#COPY ./src ./src
#COPY ./client-src ./client-src

WORKDIR /tmp/client-src

RUN npm cache verify

RUN npm install

RUN npm run build

RUN mkdir -p /tmp/src/main/resources/static

# ディレクトリ間のコピー (ここでは /tmpの下での)
RUN cp -r /tmp/client-src/build/* /tmp/src/main/resources/static
RUN mv -f /tmp/src/main/resources/static/index.html /tmp/src/main/resources/templates/.

# <<< フロント npmインストール＆ビルド

# FROM <イメージ名>[:タグ] [AS <名前>]
#   Dockerのベースイメージを公開リポジトリから取得する
#     AS <名前>：名前を付けることで以降のCOPY元として参照できる
# 
#FROM maven:3.6.3-jdk-11 AS builder
# 
# インターネットに出れないため 自力で登録したOCI上のコンテナレジストリを参照する
# 
FROM nrt.ocir.io/nrjlf5npv1v1/maven3.6.3/jdk11:1.0.0 AS builder

# WORKDIR
#   Dockerコンテナ上の作業ディレクトリ設定
#
WORKDIR /tmp

# COPY <コピー元(ローカル)> <コピー先>
# 
# Build-pipeline で指定したプライマリ・コード・リポジトリから
# Maven Build Dockerコンテナへコピー
# 

# >>>

#COPY ./src ./src
#COPY ./pom.xml .
#COPY ./settings.xml .

COPY --from=builder-react /tmp/src ./src
COPY --from=builder-react /tmp/pom.xml .
COPY --from=builder-react /tmp/settings.xml .
COPY --from=builder-react /tmp/application.properties .

# <<<

#
#【１-１】Maven ビルドを実行し、リモートリポジトリ(Nexus)にデプロイまで行なう。
# 
# RUN [コンテナ内で実行されるコマンドを書く]
# 
#   mvn：Mavenコマンド実行
#     -e：エラー時スタックトレース表示
#     -X：デバッグログ表示
#     -s：settingsファイルを指定
#     package：JAR・WAR等の成果物を生成
#     deploy：JAR・WAR等の成果物を配備
#             pom.xmlの <distributionManagement>タグに従って格納されます
#
#RUN mvn -s settings.xml package
RUN mvn -e -X -s settings.xml deploy

#
#【１-２】Tomcatコンテナイメージにビルドしたアプリケーションを配置する。
#
# FROM <イメージ名>[:タグ] [AS <名前>]
#   Dockerのベースイメージを公開リポジトリから取得する
# 
FROM nrt.ocir.io/nrjlf5npv1v1/oraclejava8/tomcat9:1.0.0

# COPY <コピー元(ローカル)> <コピー先>
#   --from=builder：事前にFROM命令で指定したイメージに付けた名前「builder」のイメージをコピー元にする
# 
COPY --from=builder /tmp/target/ebom*.war /usr/local/tomcat/webapps/ebom.war

#
#【１-３】Tomcatを起動するコマンドを追加する。
#
# EXPOSE どのポートを公開する意図なのかのドキュメントのみであり
#   実際には docker run -p 8080:8080 のように実行時に指定する
# 
EXPOSE 8080

# ENTRYPOINT 必ず実行するコマンド
# 
## ENTRYPOINT ["/usr/local/tomcat/bin/startup.sh", "run"]

# CMD コンテナに対して何もオプションを指定しなければ自動的に実行するコマンド
# 
CMD [ "/usr/local/tomcat/bin/catalina.sh", "run" ]
