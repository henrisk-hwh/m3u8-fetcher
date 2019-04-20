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
	<button onclick="play('http://img.ksbbs.com/asset/Mon_1703/05cacb4e02f9d9e.mp4', ' [3 - 11] 张靓颖 阿文 大 k ')"><h2>点击</h2></button>
	<script>
		function play(playerurl, title) {
			var url = "./player.html?url=" + playerurl + ",title=" + title;
			window.open(url, "__blank")
		}
	</script>
EOT;
print <<<EOT
	</body>

</html>
EOT;
?>