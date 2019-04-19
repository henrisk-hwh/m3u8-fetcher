<?php

$label1 = "deepblue_mainslide";
$label2 = "deepblue_mainh1";
$label3 = "deepblue_maint1";
$label4 = "deepblue_maint2";
$rs = array("http://123.abc.com", "abc", "ABC");

print <<<EOT

<!DOCTYPE html>
<html>

	<head>
		<meta charset="UTF-8">
		<title>ckplayer</title>
		
		<style type="text/css">
			body {
				margin: 0;
				padding: 0px;
				font-family: "Microsoft YaHei", YaHei, "微软雅黑", SimHei, "黑体";
				font-size: 10px;
			}
			p{
				padding-left: 2em;
			}
		</style>

	</head>

	<body>
EOT;
print <<<EOT
	<button onclick="play()"><h2>点击</h2></button>
	<script>
		var playerurl = 'http://192.168.1.103:8888/asia/media/nrCd0Pq7/local.m3u8';
		var url = "./player.html?url=" + playerurl;
		function play() {
			console.log('str: ', url);
			window.open(url, "__blank")
		}
	</script>
EOT;
print <<<EOT
	</body>

</html>
EOT;
?>