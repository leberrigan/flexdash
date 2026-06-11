#! /bin/bash -e
v1=`egrep version\": package.json`
version=`echo $v1 | sed -E 's/.*"([0-9]\..*)".*/\1/'`
echo "Generating html for version ${version}"

# produce https.html
sed -E \
  -e '/<head>/a\
    <base href="https://s3.amazonaws.com/flexdash-982081078525-us-east-1-an/'$version'/index.html" />' \
  <./dist/index.html >./docs/https.html

# produce http.html FIXME: support query string args
cat >./docs/http.html <<EOF
<html lang="en"><head>
<link rel="icon" href="./favicon.ico" />
<meta http-equiv="refresh" content="0; url=http://s3.amazonaws.com/flexdash-982081078525-us-east-1-an/${version}/index.html">
</head><body>
Redirecting to <a href="http://s3.amazonaws.com/flexdash-982081078525-us-east-1-an/${version}/index.html">
http://s3.amazonaws.com/flexdash-982081078525-us-east-1-an/${version}/index.html</a>
</body></html>
EOF
