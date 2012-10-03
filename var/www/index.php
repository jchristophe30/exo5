<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
<title>Acceptance Live Instances</title>
<link rel="shortcut icon" type="image/x-icon" href="/images/favicon.ico" />
<link href="/style.css" media="screen" rel="stylesheet" type="text/css"/>
<script type="text/javascript">

  var _gaq = _gaq || [];
  _gaq.push(['_setAccount', 'UA-1292368-28']);
  _gaq.push(['_trackPageview']);

  (function() {
    var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
    ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
  })();

</script>
</head>
<body>
<div class="UIForgePages">
  <div class="Header ClearFix"> <a href="/" class="Logo"></a><span class="AddressWeb"><?=$_SERVER['SERVER_NAME'] ?></span> </div>
  <div class="MainContent">
    <div class="TitleForgePages">Acceptance Live Instances</div>
    <div>
      <div>
        <p>&nbsp;</p>
        <p>Welcome on Acceptance Live Instances !</p>
        <p>These instances are deployed to be used for acceptance tests.</p>
        <p> Terms of usage and others documentations about this service are detailed in our <a href="https://wiki-int.exoplatform.org/x/loONAg">internal wiki</a>.</p>
        <p><br/>
        </p>
        <table class="center">
          <thead>
            <tr>
              <th colspan="2">Product</th>
              <th colspan="8">Current deployment</th>
            </tr>
            <tr>
              <th>Name</th>
              <th>Version</th>
              <th>Artifact</th>
              <th>Built</th>
              <th>Deployed</th>
              <th>URL</th>
              <th>Logs</th>
              <th>JMX</th>
              <th>Stats</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <?php
					$list = array();
					$list[] = json_decode(file_get_contents('http://acceptance.exoplatform.org/list.php'));
					$list[] = json_decode(file_get_contents('http://acceptance2.exoplatform.org/list.php'));
          sort($list);
          foreach( $list as $descriptor_array) {
            ?>
            <tr onmouseover="this.className='normalActive'" onmouseout="this.className='normal'" class="normal">
              <td><?=strtoupper($descriptor_array['PRODUCT_NAME'])?></td>
              <td><?=$descriptor_array['PRODUCT_VERSION']?></td>
              <td><a href="<?=$descriptor_array['ARTIFACT_DL_URL']?>" class="TxtBlue" title="Download <?=$descriptor_array['ARTIFACT_GROUPID']?>:<?=$descriptor_array['ARTIFACT_ARTIFACTID']?>:<?=$descriptor_array['ARTIFACT_TIMESTAMP']?> from Nexus"><img class="left" src="/images/ButDownload.gif" alt="Download" width="19" height="19" />&nbsp;<?=$descriptor_array['ARTIFACT_TIMESTAMP']?></a></td>
              <td class="<?=$descriptor_array['ARTIFACT_AGE_CLASS']?>"><?=$descriptor_array['ARTIFACT_AGE_STRING']?></td>
              <td><?php if( $descriptor_array['DEPLOYMENT_ENABLED'] ) { echo $descriptor_array['DEPLOYMENT_AGE_STRING']; } ?></td>
              <td><?php if( $descriptor_array['DEPLOYMENT_ENABLED'] ) { ?><a href="<?=$descriptor_array['DEPLOYMENT_URL']?>" class="TxtBlue" target="_blank" title="Open the instance in a new window"><?=$descriptor_array['DEPLOYMENT_URL']?></a><?php } ?></td>
              <td><?php if( $descriptor_array['DEPLOYMENT_ENABLED'] ) { ?><a href="<?=$descriptor_array['DEPLOYMENT_LOG_APPSRV_URL']?>" class="TxtOrange" title="Instance logs" target="_blank"><img src="/images/terminal_tomcat.png" width="32" height="16" alt="instance logs"  class="left" /></a><a href="<?=$descriptor_array['DEPLOYMENT_LOG_APACHE_URL']?>" class="TxtOrange" title="apache logs" target="_blank"><img src="/images/terminal_apache.png" width="32" height="16" alt="apache logs"  class="right" /></a><?php } ?></td>
              <td><?php if( $descriptor_array['DEPLOYMENT_ENABLED'] ) { ?><a href="<?=$descriptor_array['DEPLOYMENT_JMX_URL']?>" class="TxtOrange" title="jmx monitoring" target="_blank"><img src="/images/action_log.png" alt="JMX url" width="16" height="16" class="center" /></a><?php } ?></td>
              <td><?php if( $descriptor_array['DEPLOYMENT_ENABLED'] ) { ?><a href="<?=$descriptor_array['DEPLOYMENT_AWSTATS_URL']?>" class="TxtOrange" title="<?=$descriptor_array['DEPLOYMENT_URL']?> usage statistics" target="_blank"><img src="/images/server_chart.png" alt="<?=$descriptor_array['DEPLOYMENT_URL']?> usage statistics" width="16" height="16" class="center" /></a><?php } ?></td>
              <?php
            if ($descriptor_array['DEPLOYMENT_STATUS']=="Up")
              $status="<img width=\"16\" height=\"16\" src=\"/images/green_ball.png\" alt=\"Up\"  class=\"left\"/>&nbsp;Up";
            else
              $status="<img width=\"16\" height=\"16\" src=\"/images/red_ball.png\" alt=\"Down\"  class=\"left\"/>&nbsp;Down !";
            ?>
              <td><?php if( $descriptor_array['DEPLOYMENT_ENABLED'] ) { echo "status; } ?></td>
            </tr>
            <?php 
          } 
          ?>
          </tbody>
        </table>
        <p>&nbsp;</p>
        <p>Each instance can be accessed using JMX with the  URL linked to the monitoring icon and these credentials : <span class="TxtBoldContact">acceptanceMonitor</span> / <span class="TxtBoldContact">monitorAcceptance!</span></p>
        <p><a href="/stats/awstats.pl?config=<?=$_SERVER['SERVER_NAME'] ?>" class="TxtBlue" title="http://<?=$_SERVER['SERVER_NAME'] ?> usage statistics" target="_blank"><img src="/images/server_chart.png" alt="Statistics" width="16" height="16" class="left" />http://<?=$_SERVER['SERVER_NAME'] ?> usage statistics</a></p>
      </div>
    </div>
  </div>
  <div class="Footer">eXo Platform SAS</div>
</div>
</body>
</html>
