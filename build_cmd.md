docker build --build-arg http_proxy=http://127.0.0.1:12347 --build-arg https_proxy=http://127.0.0.1:12347 --network=host -t justlikemaki/openclaw-docker-cn-im:latest .

docker exec -it -u node 950c bash

curl -I -x http://127.0.0.1:12346 https://www.google.com

docker-compose down && docker-compose up
docker-compose restart openclaw-gateway


npx -y @tencent-weixin/openclaw-weixin-cli@latest install
openclaw plugins install @sunnoy/wecom
npx -y @larksuite/openclaw-lark install