$host.ui.RawUI.WindowTitle="执行任务脚本"
$taskScript = (Read-Host "请输入要执行的任务脚本的路径 （默认为同路径下的 tasks.ps1）")
if( !$taskScript ){
    $taskScript = "tasks.ps1"
}else{
    while( !(Test-Path $taskScript) ){
        Write-Host -ForegroundColor Red "不存在 $taskScript"
        $taskScript = (Read-Host "请输入要执行的任务脚本的路径 （默认为同路径下的 tasks.ps1）")
    }
}

# 剔除重复
$contentOri = $( Get-Content $taskScript )
$contentUniqueTrimmed = @()
$contentUnique = @()
$linesDup = @()
$linesUnique = @()
for( $i=0; $i -lt $contentOri.length; $i++ ){
    if( !($contentOri[$i].Trim() -match "^#") ){
        if( $contentUniqueTrimmed.Contains($contentOri[ $i ].Trim().Split("`#")[0].Trim()) ){
            $linesDup += $i
        }else{
            $contentUniqueTrimmed += $contentOri[ $i ].Trim().Split("`#")[0].Trim()
            $linesUnique += $i
        }
    }
}
if( $linesDup.length -ne 0 ){
    Write-Host "下列任务重复："
    $linesDup | ForEach {
        "L$($_+1)", " ", $contentOri[ $_ ] | Join-String
    }
    $opt = $(Read-Host "是否剔除所有重复任务？默认剔除，回复N或n以不剔除")
    if( $opt -ne "N" ){
        $linesUnique | ForEach {
            $contentUnique += $contentOri[ $_ ]
        }
        Set-Content $taskScript $contentUnique 
    }
}

$isOK=$False
$cntBeingDone = 0
while( !$isOK ){
    $cmds = $(Get-Content $taskScript)
    $i=0
    while( ($cmds[$i].Trim() -match "^#") -OR ([string]::IsNullOrEmpty($cmds[$i].Trim())) ){
        $i++
        if( $i -eq $cmds.length ){
            $isOK=$True
            echo "全都完成"
            break
        }
    }
    if( !$isOK ){
        $cntBeingDone++
        $todo=$cmds[$i]
        $cmds[$i]=$( "# 正在执行 ", $todo | Join-String )
        Set-Content $taskScript $cmds
        try {
            $host.ui.RawUI.WindowTitle="执行$taskScript L$($i+1) `#$cntBeingDone"
            Invoke-Expression $todo
            $res="# 已完成 "
        } catch {
            $res="# 出错 "
        }
        $cmds = $(Get-Content $taskScript)

        if( $cmds[$i] -match "^`# 正在执行 " ){
            if( $cmds[$i].Split("`# 正在执行 ")[1].Trim() -eq $todo.Trim() ){
                # 若刚执行完的命令仍在命令脚本的同一行中
                $cmds[$i]=$( $res, $todo | Join-String )
            }
        }else{
            # 若刚执行完的命令在命令脚本的不同行中
            $isFoundInTaskScript = $False
            for( $j=0; $j -lt $cmds.length; $j++ ){
                if( $cmds[$j] -match "^`# 正在执行 " ){
                    if( $cmds[$j].Split("`# 正在执行 ")[1].Trim() -eq $todo.Trim() ){
                        $cmds[$j]=$( $res, $todo | Join-String )
                        $isFoundInTaskScript = $True
                        break
                    }
                }
            }
            # 若刚执行完的命令仍不在命令脚本中
            if( !$isFoundInTaskScript ){
                $cmds += $( "`# 已被删除 ", $res, $todo | Join-String )
            }
        }

        Set-Content $taskScript $cmds
    }
}
