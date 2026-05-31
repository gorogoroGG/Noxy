module.exports = {
  apps: [
    {
      name: 'noxy-bot',
      script: 'dist/index.js',
      // クラッシュしたら自動再起動
      autorestart: true,
      // 無限ループ再起動を防ぐ（1秒未満で落ちた場合は再起動しない）
      min_uptime: '1s',
      max_restarts: 10,
      // ログファイルの場所
      out_file: 'logs/out.log',
      error_file: 'logs/error.log',
      merge_logs: true,
      // 環境変数は .env から読む（dotenv が担当するので PM2 側は不要）
    },
  ],
};
