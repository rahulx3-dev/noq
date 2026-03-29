$outDir = "C:\Users\HP\qcutapp\stitch_ui"
if (!(Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir
}

$urls = @{
    "s1_profile_settings.html" = "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sXzYzMTNlYzk0YWNlNjRmZTdiY2ZlMmIwMGUxODE1MjYzEgsSBxCS09fYzhIYAZIBIwoKcHJvamVjdF9pZBIVQhM1NzUxNzk3MDYxNjY3NjcyNzA4&filename=&opi=89354086"
    "s2_canteen_details.html" = "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sXzcyNjFkODFhNTBiNjQ1ZGVhMGE1YTY5ZDBmZjA2ZDdjEgsSBxCS09fYzhIYAZIBIwoKcHJvamVjdF9pZBIVQhM1NzUxNzk3MDYxNjY3NjcyNzA4&filename=&opi=89354086"
    "s3_session_scheduler.html" = "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sX2MzMDllYTFhYjFkZTQ1YTBhNjZjMDM0NjJjMjFjNjgyEgsSBxCS09fYzhIYAZIBIwoKcHJvamVjdF9pZBIVQhM1NzUxNzk3MDYxNjY3NjcyNzA4&filename=&opi=89354086"
    "s4_stock_carry_over.html" = "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sX2Y1Yjg0MDQ4NTNiZDRlYWJiMmFlYjQxY2YzYjA2MDA1EgsSBxCS09fYzhIYAZIBIwoKcHJvamVjdF9pZBIVQhM1NzUxNzk3MDYxNjY3NjcyNzA4&filename=&opi=89354086"
    "s5_food_categories.html" = "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sXzY4NzQ3YjQ1MmY2YTQ4MGQ4OWJhNTU2NTFjM2U1ZjFkEgsSBxCS09fYzhIYAZIBIwoKcHJvamVjdF9pZBIVQhM1NzUxNzk3MDYxNjY3NjcyNzA4&filename=&opi=89354086"
    "s6_session_defaults.html" = "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sXzM4YTU2YWNlYTBlMTQzOTZiMGZlZWM3YzM2NTY4OTJkEgsSBxCS09fYzhIYAZIBIwoKcHJvamVjdF9pZBIVQhM1NzUxNzk3MDYxNjY3NjcyNzA4&filename=&opi=89354086"
    "s7_edit_item_expandable.html" = "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sXzExMjhiNGJhMGVmNjRiMGQ5ZmQxNzY1NGExOThhMjQ1EgsSBxCS09fYzhIYAZIBIwoKcHJvamVjdF9pZBIVQhM1NzUxNzk3MDYxNjY3NjcyNzA4&filename=&opi=89354086"
    "s8_add_staff.html" = "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sXzUyYWQyZmMwMjYxNDRhYzM5YTMxODE0ZWE2YzI0YWNkEgsSBxCS09fYzhIYAZIBIwoKcHJvamVjdF9pZBIVQhM1NzUxNzk3MDYxNjY3NjcyNzA4&filename=&opi=89354086"
    "s9_add_new_item_manage_menu.html" = "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sX2M0YWEwYTM4ZTk2MjQ1MTZiYjVmNWI1YTc4YzJlOWU3EgsSBxCS09fYzhIYAZIBIwoKcHJvamVjdF9pZBIVQhM1NzUxNzk3MDYxNjY3NjcyNzA4&filename=&opi=89354086"
    "s10_live_menu.html" = "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sXzA0MWVjMjY5YTZmYzQwY2Y5YWJiOGI2YmJkMjhiMTc0EgsSBxCS09fYzhIYAZIBIwoKcHJvamVjdF9pZBIVQhM1NzUxNzk3MDYxNjY3NjcyNzA4&filename=&opi=89354086"
    "s11_menu_release_nav_bar.html" = "https://contribution.usercontent.google.com/download?c=CgthaWRhX2NvZGVmeBJ7Eh1hcHBfY29tcGFuaW9uX2dlbmVyYXRlZF9maWxlcxpaCiVodG1sX2U2ZThiZjNlMTkyOTQ4MjQ5ODJhMGY0NTQ1NmIwNWRhEgsSBxCS09fYzhIYAZIBIwoKcHJvamVjdF9pZBIVQhM1NzUxNzk3MDYxNjY3NjcyNzA4&filename=&opi=89354086"
}

foreach ($key in $urls.Keys) {
    $url = $urls[$key]
    $dest = Join-Path $outDir $key
    Invoke-WebRequest -Uri $url -OutFile $dest | Out-Null
}
Write-Output "Downloaded all screens."
