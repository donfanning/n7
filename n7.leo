<?xml version="1.0" encoding="utf-8"?>
<!-- Created by Leo (http://leoeditor.com/leo_toc.html) -->
<?xml-stylesheet ekr_test?>
<leo_file xmlns:leo="http://www.leo-editor.org/2011/leo" >
<leo_header file_format="2" tnodes="0" max_tnode_index="0" clone_windows="0"/>
<globals body_outline_ratio="0.5" body_secondary_ratio="0.5">
	<global_window_position top="50" left="50" height="500" width="700"/>
	<global_log_window_position top="0" left="0" height="0" width="0"/>
</globals>
<preferences/>
<find_panel_settings/>
<vnodes>
<v t="jkuan.20140102223152.1607"><vh>@button Set headline from N7::*() { in the body</vh></v>
<v t="jkuan.20140102144155.1729"><vh>@settings</vh>
<v t="jkuan.20140102144155.1730"><vh>@string view-rendered-default-kind = md</vh></v>
<v t="jkuan.20140102223152.1587"><vh>@enabled-plugins</vh></v>
<v t="jkuan.20140107194142.1911"><vh>@bool scripting-at-script-nodes = true</vh></v>
</v>
<v t="jkuan.20140107194142.1912"><vh>@script</vh></v>
<v t="jkuan.20140102142439.1727" a="E"><vh>TODOs</vh>
<v t="jkuan.20140107111208.1901"><vh>ansible module integration</vh></v>
<v t="jkuan.20140107111208.1903"><vh>show colorized output</vh></v>
<v t="jkuan.20140107111208.1902"><vh>show also stderr for tasks with non-zero exit status</vh></v>
</v>
<v t="jkuan.20131231170128.1692" a="E"><vh>/</vh>
<v t="jkuan.20140102135512.1728"><vh>@edit README.md</vh></v>
<v t="jkuan.20140106102002.1897" a="E"><vh>tests</vh>
<v t="jkuan.20140107111208.1905"><vh>@file setup.sh</vh></v>
<v t="jkuan.20140106102002.1899"><vh>@file basic.n7</vh></v>
<v t="jkuan.20140107111208.1904"><vh>@file test-n7-cmdline</vh></v>
</v>
<v t="jkuan.20140101001347.1707" a="E"
expanded="jkuan.20140105132438.2228,jkuan.20140109170044.1915,"><vh>@shadow bin/n7</vh></v>
</v>
</vnodes>
<tnodes>
<t tx="jkuan.20131231170128.1692">@color
@language shell

</t>
<t tx="jkuan.20140102142439.1727">@language python
</t>
<t tx="jkuan.20140102144155.1729"></t>
<t tx="jkuan.20140102144155.1730"></t>
<t tx="jkuan.20140102223152.1587"></t>
<t tx="jkuan.20140102223152.1607">@language python
@tabwidth -4

for p in c.getSelectedPositions():
    for line in p.b.split("\n"):
        line = line.strip()
        if line.startswith("N7::") and line.endswith("() {"):
            p.h = line[:-4]
            break
        
        
</t>
<t tx="jkuan.20140106102002.1897">@path tests</t>
<t tx="jkuan.20140107111208.1901" annotate="7d71002855087072696f7269747971014b03550a707269736574646174657102550a323031342d30312d30377103752e" lineYOffset="4b032e" icons="5d71007d71012855026f6e71025505766e6f64657103550577686572657104550e6265666f7265486561646c696e6571055507796f666673657471064b005507786f666673657471074b02550466696c657108587c0000002f4170706c69636174696f6e732f4c656f2d342e31312d66696e616c2f7669727475616c2f6c69622f707974686f6e322e372f736974652d7061636b616765732f6c656f2d342e31312e66696e616c5f6275696c645f353032302d7079322e372e6567672f6c656f2f49636f6e732f636c656f2f707269332e706e677109550478706164710a4b01550474797065710b68085508636c656f49636f6e710c550131710d550772656c50617468710e580d000000636c656f2f707269332e706e67710f75612e"></t>
<t tx="jkuan.20140107111208.1902">@killcolor

Or...not. This complicates the output as we'll need to distinguish between outputs coming from stdout and stderr.
The user can redirect stderr to stdout manually in the remote task, or we might provide a command-line option
for doing this to all remote tasks.</t>
<t tx="jkuan.20140107111208.1903"></t>
<t tx="jkuan.20140107194142.1911"></t>
<t tx="jkuan.20140107194142.1912">c.k.simulateCommand('toggle-split-direction')
</t>
</tnodes>
</leo_file>
