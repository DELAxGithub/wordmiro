# Miro拡張機能「wordmiro」開発セットアップ手順

このドキュメントは、Miro拡張機能として「wordmiro」を開発するための初期セットアップ手順をまとめたものです。

## 1. 前提条件

-   [Miro](https://miro.com/)のアカウントを持っていること。
-   [Node.js](https://nodejs.org/)（LTS版を推奨）がローカルマシンにインストールされていること。

## 2. Miroでのアプリ登録と設定

まず、Miroの管理画面で開発するアプリの情報を登録し、後で必要になる認証情報を取得します。

1.  Miroにログインし、[開発者向けアプリ管理ページ](https://miro.com/app/settings/user-profile/apps)にアクセスします。
2.  `+ Create new app` ボタンをクリックします。
3.  アプリ名（例: `wordmiro Dev`）を入力し、開発チームを選択してアプリを作成します。
4.  **App credentials** セクションで、`Client ID` と `Client secret` を確認します。（後でバックエンドで使用する可能性があります）
5.  **Permissions** セクションで、アプリに必要な権限（Scope）を設定します。wordmiroの場合、最低限以下が必要になります。
    *   `boards:read`
    *   `boards:write`
6.  ページ上部の `Install app and get OAuth token` をクリックし、開発用チームにアプリをインストールして、アクセストークンを発行します。このトークンはテスト時に使用します。

> **注意:** これらの認証情報（特にClient secretやアクセストークン）は、Gitリポジトリなどに直接コミットしないように注意してください。

## 3. ローカル開発環境のセットアップ

次に、コマンドラインツールを使って、ローカルにプロジェクトの雛形を作成します。

1.  ターミナルを開き、プロジェクトを置きたいディレクトリに移動します。
2.  以下のコマンドを実行します。

    ```bash
    npx create-miro-app@latest
    ```

3.  対話形式でいくつか質問されるので、以下のように回答します。
    *   **What is your application name?**
        *   `wordmiro-miro-app` と入力します。
    *   **Choose a template:**
        *   `React` を選択します。（他のフレームワークに慣れていればそれでも可）
    *   **Will you be using the Miro REST API?**
        *   `Yes` を選択します。（バックエンド連携で必要）
    *   **What language will you be using?**
        *   `TypeScript` を選択します。（型安全のため推奨）

4.  コマンドが完了すると、`wordmiro-miro-app` という名前のディレクトリが作成されます。

## 4. 開発サーバーの起動と動作確認

1.  作成されたプロジェクトディレクトリに移動します。

    ```bash
    cd wordmiro-miro-app
    ```

2.  必要なライブラリをインストールします。

    ```bash
    npm install
    ```

3.  開発サーバーを起動します。

    ```bash
    npm run dev
    ```

4.  ターミナルに表示されるURL（例: `http://localhost:3000`）を開くと、Miroのボード選択画面が表示されます。ボードを選択すると、作成したアプリの "Hello World" が表示されます。

これで、VSCodeで `wordmiro-miro-app` フォルダを開けば、すぐに開発を始めることができます。

## 5. 次のステップ

-   **UIの実装:** `src/app.tsx` などを編集し、Web SDKを使ってMiroボード上のUIを構築していきます。
-   **バックエンドの構築:** GPT APIを安全に呼び出すためのバックエンドサーバーを別途構築します。（例: Node.js + Express, Python + FastAPIなど）
-   **公式ドキュメントの参照:** 詳細は [Miro Developer Platform](https://developers.miro.com/) を参照してください。
