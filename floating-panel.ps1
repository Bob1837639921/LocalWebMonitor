$ErrorActionPreference = "SilentlyContinue"

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Drawing

$createdMutex = $false
$mutex = New-Object System.Threading.Mutex($true, "LocalWebMonitorFloatingPanel", [ref]$createdMutex)
if (-not $createdMutex) { exit }

function Z([string]$value) {
  return [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($value))
}

$script:I18n = @{
  zh = @{
    AppTitle = (Z "5pys5Zyw572R6aG155uR5ZCs")
    Subtitle = "Local Web Monitor"
    AutoScan = (Z "6Ieq5Yqo5omr5o+P5bey5byA5ZCv")
    Monitoring = (Z "55uR5o6n5Lit")
    Running = (Z "6L+Q6KGM5Lit")
    WebEntries = (Z "5pys5Zyw5YWl5Y+j")
    ApiServices = (Z "5o6l5Y+j5pyN5Yqh")
    OpenableWeb = (Z "5Y+v5omT5byA572R6aG1")
    Api = (Z "5o6l5Y+j")
    Starting = (Z "5ZCv5Yqo5Lit")
    Offline = (Z "5bey56a757q/")
    LastUpdated = (Z "5pyA5ZCO5pu05paw")
    Healthy = (Z "6L+e5o6l5q2j5bi4")
    Pin = (Z "572u6aG2")
    Scan = (Z "5omr5o+P")
    Open = (Z "5omT5byA")
    EmptyTitle = (Z "5pqC5peg6L+Q6KGM5Lit55qE5pys5Zyw572R6aG1")
    EmptyHint = (Z "5ZCv5Yqo5YmN56uv6aG555uu5ZCO5Lya6Ieq5Yqo5Ye6546w5Zyo6L+Z6YeM")
    FooterScan = (Z "6Ieq5Yqo5omr5o+P5q+PIDMg56eS")
    TotalPorts = (Z "5YWx55uR5ZCs")
    Ports = (Z "5Liq56uv5Y+j")
    Scanning = (Z "5q2j5Zyo5omr5o+PLi4u")
    LocalPage = (Z "5pys5Zyw572R6aG1")
    JustNow = (Z "5Yia5Yia")
  }
  en = @{
    AppTitle = "Local Web Monitor"
    Subtitle = "Local Web Monitor"
    AutoScan = "Auto scan is on"
    Monitoring = "Monitoring"
    Running = "Running"
    WebEntries = "Local entries"
    ApiServices = "API services"
    OpenableWeb = "Openable pages"
    Api = "API"
    Starting = "Starting"
    Offline = "Offline"
    LastUpdated = "Last updated"
    Healthy = "Connection healthy"
    Pin = "Pin"
    Scan = "Scan"
    Open = "Open"
    EmptyTitle = "No local pages running"
    EmptyHint = "Start a frontend project and it will appear here."
    FooterScan = "Auto scan every 3 sec"
    TotalPorts = "Watching"
    Ports = "ports"
    Scanning = "Scanning..."
    LocalPage = "Local page"
    JustNow = "just now"
  }
}

function T([string]$key) { return $script:I18n[$script:lang][$key] }

$script:Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:Assets = Join-Path $script:Root "assets"
New-Item -ItemType Directory -Force -Path $script:Assets | Out-Null

$script:lang = "zh"
$script:services = @()
$script:startingServices = @()
$script:offlineServices = @()
$script:lastPortCount = 0
$script:lastScanStarted = [DateTime]::MinValue
$script:lastUpdated = $null
$script:scanJob = $null
$script:scanIntervalMs = 3000

function New-SolidBrush($color) {
  return New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml($color))
}

function Save-Logo($name, $text, $bg, $fg) {
  $path = Join-Path $script:Assets "$name.png"
  if (Test-Path $path) { return $path }
  $bmp = New-Object System.Drawing.Bitmap 96, 96
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.Clear([System.Drawing.Color]::Transparent)
  $rect = New-Object System.Drawing.Rectangle 8, 8, 80, 80
  $brush = New-SolidBrush $bg
  $g.FillEllipse($brush, $rect)
  $font = New-Object System.Drawing.Font("Segoe UI", 32, [System.Drawing.FontStyle]::Bold)
  $fmt = New-Object System.Drawing.StringFormat
  $fmt.Alignment = [System.Drawing.StringAlignment]::Center
  $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
  $fgBrush = New-SolidBrush $fg
  $g.DrawString($text, $font, $fgBrush, $rect, $fmt)
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose(); $brush.Dispose(); $fgBrush.Dispose(); $font.Dispose()
  return $path
}

function Ensure-Assets {
  Save-Logo "radar" "L" "#053F32" "#18D989" | Out-Null
  Save-Logo "vite" "V" "#6D3BFF" "#FFE45E" | Out-Null
  Save-Logo "next" "N" "#111111" "#FFFFFF" | Out-Null
  Save-Logo "react" "R" "#E9FBFF" "#00A6D6" | Out-Null
  Save-Logo "vue" "V" "#E9FFF3" "#16A56B" | Out-Null
  Save-Logo "svelte" "S" "#FFF0E9" "#FF4E18" | Out-Null
  Save-Logo "nuxt" "N" "#E8FFF4" "#00B87A" | Out-Null
  Save-Logo "angular" "A" "#FFF0F4" "#DD0031" | Out-Null
  Save-Logo "astro" "A" "#F3F0FF" "#111111" | Out-Null
  Save-Logo "html" "H" "#EEF3F8" "#64748B" | Out-Null
}

Ensure-Assets

function Get-AssetPath($framework) {
  $key = ([string]$framework).ToLowerInvariant()
  if ($key.Contains("http") -or $key.Contains("api") -or $key.Contains("json")) { return Join-Path $script:Assets "api.png" }
  return Join-Path $script:Assets "web.png"
}

function ImageSource($path) {
  $img = New-Object System.Windows.Media.Imaging.BitmapImage
  $img.BeginInit()
  $img.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
  $img.UriSource = New-Object System.Uri($path, [System.UriKind]::Absolute)
  $img.EndInit()
  $img.Freeze()
  return $img
}

function XamlReader($xaml) {
  $reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
  return [Windows.Markup.XamlReader]::Load($reader)
}

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Local Web Monitor" Width="560" Height="680" MinWidth="520" MinHeight="560"
        WindowStyle="None" ResizeMode="CanResizeWithGrip" AllowsTransparency="True"
        Background="Transparent" Topmost="True" ShowInTaskbar="True">
  <Border x:Name="Chrome" Margin="6" CornerRadius="14" Background="#F8FAFC" BorderBrush="#D8E0EA" BorderThickness="1">
    <Border.Effect>
      <DropShadowEffect Color="#334155" Opacity="0.18" BlurRadius="22" ShadowDepth="5"/>
    </Border.Effect>
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="78"/>
        <RowDefinition Height="116"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="34"/>
      </Grid.RowDefinitions>

      <Grid x:Name="Header" Grid.Row="0" Margin="18,12,18,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="44"/>
          <ColumnDefinition Width="210"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="210"/>
        </Grid.ColumnDefinitions>
        <Border Width="42" Height="42" CornerRadius="21" Background="#E8F7F0" VerticalAlignment="Center">
          <Image x:Name="LogoImage" Width="36" Height="36"/>
        </Border>
        <StackPanel Grid.Column="1" Margin="10,0,0,0" VerticalAlignment="Center">
          <TextBlock x:Name="TitleText" FontSize="17" FontWeight="Bold" Foreground="#111827" LineHeight="22"/>
          <TextBlock x:Name="SubtitleText" FontSize="12" Foreground="#64748B" Margin="0,3,0,0"/>
        </StackPanel>
        <StackPanel Grid.Column="3" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,0,0">
          <Label x:Name="PinButton" Width="42" Height="30" Margin="0,0,8,0" Padding="0" HorizontalContentAlignment="Center" VerticalContentAlignment="Center" Background="#FFFFFF" Foreground="#009B63" BorderBrush="#C8D2DF" BorderThickness="1" FontSize="12" Cursor="Hand"/>
          <Label x:Name="ScanButton" Width="42" Height="30" Margin="0,0,8,0" Padding="0" HorizontalContentAlignment="Center" VerticalContentAlignment="Center" Background="#FFFFFF" Foreground="#009B63" BorderBrush="#C8D2DF" BorderThickness="1" FontSize="12" Cursor="Hand"/>
          <Label x:Name="LangButton" Width="58" Height="30" Margin="0,0,8,0" Padding="0" HorizontalContentAlignment="Center" VerticalContentAlignment="Center" Background="#FFFFFF" Foreground="#009B63" BorderBrush="#C8D2DF" BorderThickness="1" FontSize="12" FontWeight="Bold" Cursor="Hand"/>
          <Button x:Name="MinButton" Content="-" Width="24" Height="30" Padding="0" HorizontalContentAlignment="Center" VerticalContentAlignment="Center" Background="Transparent" BorderThickness="0" Foreground="#64748B" FontSize="18" Cursor="Hand"/>
          <Button x:Name="CloseButton" Content="X" Width="24" Height="30" Padding="0" HorizontalContentAlignment="Center" VerticalContentAlignment="Center" Background="Transparent" BorderThickness="0" Foreground="#475569" FontSize="14" Cursor="Hand"/>
        </StackPanel>
      </Grid>

      <Border Grid.Row="1" Margin="18,0,18,12" CornerRadius="13" Background="#FFFFFF" BorderBrush="#DDE5EF" BorderThickness="1">
        <Grid Margin="18,14">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="138"/>
            <ColumnDefinition Width="1"/>
            <ColumnDefinition Width="94"/>
            <ColumnDefinition Width="1"/>
            <ColumnDefinition Width="*"/>
          </Grid.ColumnDefinitions>
          <StackPanel Grid.Column="0" VerticalAlignment="Center">
            <StackPanel Orientation="Horizontal">
              <Ellipse Width="12" Height="12" Fill="#10B981" Margin="0,4,10,0"/>
              <TextBlock x:Name="MonitoringText" FontSize="15" FontWeight="Bold" Foreground="#111827"/>
            </StackPanel>
            <TextBlock x:Name="AutoScanText" FontSize="12" Foreground="#64748B" Margin="22,7,0,0"/>
          </StackPanel>
          <Border Grid.Column="1" Background="#E2E8F0" Margin="0,10"/>
          <StackPanel Grid.Column="2" HorizontalAlignment="Center" VerticalAlignment="Center">
            <TextBlock x:Name="RunningCountText" Text="0" FontSize="28" FontWeight="Bold" Foreground="#009B63" HorizontalAlignment="Center"/>
            <TextBlock x:Name="RunningText" FontSize="12" Foreground="#475569" HorizontalAlignment="Center"/>
          </StackPanel>
          <Border Grid.Column="3" Background="#E2E8F0" Margin="0,10"/>
          <StackPanel Grid.Column="4" Margin="14,0,0,0" VerticalAlignment="Center">
            <TextBlock x:Name="LastUpdatedText" FontSize="12" Foreground="#64748B"/>
            <TextBlock x:Name="LastUpdatedValue" Text="--:--:--" FontSize="18" FontWeight="Bold" Foreground="#111827" Margin="0,4,0,0"/>
            <StackPanel Orientation="Horizontal" Margin="0,6,0,0">
              <Ellipse Width="8" Height="8" Fill="#10B981" Margin="0,4,7,0"/>
              <TextBlock x:Name="HealthText" FontSize="12" FontWeight="SemiBold" Foreground="#009B63"/>
            </StackPanel>
          </StackPanel>
        </Grid>
      </Border>

      <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="0,0,2,0">
        <StackPanel x:Name="ServiceStack" Margin="18,0,18,0"/>
      </ScrollViewer>

      <Grid Grid.Row="3" Margin="18,0,18,0">
        <TextBlock x:Name="FooterText" VerticalAlignment="Center" FontSize="12" Foreground="#64748B"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
          <Ellipse Width="8" Height="8" Fill="#10B981" Margin="0,0,8,0"/>
          <TextBlock Text="v1.0.0" FontSize="12" Foreground="#64748B"/>
        </StackPanel>
      </Grid>
    </Grid>
  </Border>
</Window>
"@

$window = XamlReader $xaml
$Chrome = $window.FindName("Chrome")
$Header = $window.FindName("Header")
$LogoImage = $window.FindName("LogoImage")
$TitleText = $window.FindName("TitleText")
$SubtitleText = $window.FindName("SubtitleText")
$PinButton = $window.FindName("PinButton")
$ScanButton = $window.FindName("ScanButton")
$LangButton = $window.FindName("LangButton")
$MinButton = $window.FindName("MinButton")
$CloseButton = $window.FindName("CloseButton")
$MonitoringText = $window.FindName("MonitoringText")
$AutoScanText = $window.FindName("AutoScanText")
$RunningCountText = $window.FindName("RunningCountText")
$RunningText = $window.FindName("RunningText")
$LastUpdatedText = $window.FindName("LastUpdatedText")
$LastUpdatedValue = $window.FindName("LastUpdatedValue")
$HealthText = $window.FindName("HealthText")
$ServiceStack = $window.FindName("ServiceStack")
$FooterText = $window.FindName("FooterText")

$LogoImage.Source = ImageSource (Join-Path $script:Assets "radar.png")

function Brush($hex) {
  return New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($hex))
}

function SectionHeader($label, $count, $accent, $soft) {
  $border = New-Object System.Windows.Controls.Border
  $border.Height = 40
  $border.Margin = "0,0,0,0"
  $grid = New-Object System.Windows.Controls.Grid
  $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "6" }))
  $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "Auto" }))
  $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "Auto" }))
  $rail = New-Object System.Windows.Shapes.Rectangle
  $rail.Width = 4; $rail.Height = 28; $rail.RadiusX = 2; $rail.RadiusY = 2
  $rail.Fill = Brush $accent; $rail.VerticalAlignment = "Center"
  [System.Windows.Controls.Grid]::SetColumn($rail, 0); $grid.Children.Add($rail) | Out-Null
  $text = New-Object System.Windows.Controls.TextBlock
  $text.Text = $label; $text.FontSize = 17; $text.FontWeight = "Bold"; $text.Foreground = Brush "#111827"; $text.Margin = "10,0,12,0"; $text.VerticalAlignment = "Center"
  [System.Windows.Controls.Grid]::SetColumn($text, 1); $grid.Children.Add($text) | Out-Null
  $pill = New-Object System.Windows.Controls.Border
  $pill.CornerRadius = "12"; $pill.Background = Brush $soft; $pill.Padding = "9,3"; $pill.VerticalAlignment = "Center"
  $pillText = New-Object System.Windows.Controls.TextBlock
  $pillText.Text = [string]$count; $pillText.Foreground = Brush $accent; $pillText.FontWeight = "Bold"; $pillText.FontSize = 13
  $pill.Child = $pillText
  [System.Windows.Controls.Grid]::SetColumn($pill, 2); $grid.Children.Add($pill) | Out-Null
  $border.Child = $grid
  return $border
}

function RowView($service, $kind) {
  $accent = "#009B63"; $soft = "#E8F7F0"
  if ($kind -eq "starting") { $accent = "#F28C00"; $soft = "#FFF3DE" }
  if ($kind -eq "offline") { $accent = "#94A3B8"; $soft = "#F1F5F9" }

  $row = New-Object System.Windows.Controls.Border
  $row.Height = 86
  $row.Margin = "0,0,0,1"
  $row.Background = Brush "#FFFFFF"
  $row.BorderBrush = Brush "#E6ECF2"
  $row.BorderThickness = "0,0,0,1"
  $row.Cursor = "Hand"

  $grid = New-Object System.Windows.Controls.Grid
  $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "7" }))
  $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "28" }))
  $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "54" }))
  $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "*" }))
  $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "74" }))

  $rail = New-Object System.Windows.Shapes.Rectangle
  $rail.Width = 4; $rail.Height = 64; $rail.RadiusX = 2; $rail.RadiusY = 2
  $rail.Fill = Brush $accent; $rail.VerticalAlignment = "Center"; $rail.HorizontalAlignment = "Left"
  [System.Windows.Controls.Grid]::SetColumn($rail, 0); $grid.Children.Add($rail) | Out-Null

  $dot = New-Object System.Windows.Shapes.Ellipse
  $dot.Width = 10; $dot.Height = 10; $dot.Fill = Brush $accent; $dot.VerticalAlignment = "Center"; $dot.HorizontalAlignment = "Center"
  [System.Windows.Controls.Grid]::SetColumn($dot, 1); $grid.Children.Add($dot) | Out-Null

  $iconBorder = New-Object System.Windows.Controls.Border
  $iconBorder.Width = 38; $iconBorder.Height = 38; $iconBorder.CornerRadius = "10"; $iconBorder.Background = Brush "#FFFFFF"; $iconBorder.BorderBrush = Brush "#E2E8F0"; $iconBorder.BorderThickness = "1"; $iconBorder.VerticalAlignment = "Center"
  $img = New-Object System.Windows.Controls.Image
  $img.Width = 30; $img.Height = 30; $img.Source = ImageSource (Get-AssetPath $service.Framework)
  $iconBorder.Child = $img
  [System.Windows.Controls.Grid]::SetColumn($iconBorder, 2); $grid.Children.Add($iconBorder) | Out-Null

  $info = New-Object System.Windows.Controls.Grid
  $info.Margin = "4,12,8,10"
  $info.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "32" }))
  $info.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{ Height = "28" }))
  $info.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "150" }))
  $info.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "*" }))

  $name = New-Object System.Windows.Controls.TextBlock
  $name.Text = if ([string]::IsNullOrWhiteSpace([string]$service.Title)) { T "LocalPage" } else { [string]$service.Title }
  $name.FontSize = 16; $name.FontWeight = "Bold"; $name.Foreground = Brush "#111827"; $name.TextTrimming = "CharacterEllipsis"; $name.VerticalAlignment = "Center"
  [System.Windows.Controls.Grid]::SetRow($name, 0); [System.Windows.Controls.Grid]::SetColumn($name, 0); $info.Children.Add($name) | Out-Null

  $url = New-Object System.Windows.Controls.TextBlock
  $url.Text = [string]$service.Url; $url.FontSize = 13; $url.Foreground = Brush "#64748B"; $url.TextTrimming = "CharacterEllipsis"; $url.VerticalAlignment = "Center"; $url.Margin = "8,0,0,0"
  [System.Windows.Controls.Grid]::SetRow($url, 0); [System.Windows.Controls.Grid]::SetColumn($url, 1); $info.Children.Add($url) | Out-Null

  $pills = New-Object System.Windows.Controls.StackPanel
  $pills.Orientation = "Horizontal"; $pills.VerticalAlignment = "Center"
  foreach ($txt in @([string]$service.Port, [string]$service.Framework)) {
    $pill = New-Object System.Windows.Controls.Border
    $pill.CornerRadius = "8"; $pill.Background = Brush $soft; $pill.Padding = "10,4"; $pill.Margin = "0,0,8,0"
    $pt = New-Object System.Windows.Controls.TextBlock
    $pt.Text = $txt; $pt.Foreground = Brush $accent; $pt.FontWeight = "SemiBold"; $pt.FontSize = 13
    $pill.Child = $pt; $pills.Children.Add($pill) | Out-Null
  }
  [System.Windows.Controls.Grid]::SetRow($pills, 1); [System.Windows.Controls.Grid]::SetColumnSpan($pills, 2); $info.Children.Add($pills) | Out-Null

  [System.Windows.Controls.Grid]::SetColumn($info, 3); $grid.Children.Add($info) | Out-Null

  $open = New-Object System.Windows.Controls.Button
  $open.Content = T "Open"; $open.Width = 58; $open.Height = 32; $open.Margin = "0,0,10,0"; $open.VerticalAlignment = "Center"; $open.HorizontalAlignment = "Right"; $open.Background = Brush "#FFFFFF"; $open.BorderBrush = Brush "#DDE5EF"; $open.Foreground = Brush "#111827"; $open.Cursor = "Hand"
  $targetUrl = [string]$service.Url
  $open.Add_Click({ param($sender,$eventArgs) Start-Process $targetUrl })
  [System.Windows.Controls.Grid]::SetColumn($open, 4); $grid.Children.Add($open) | Out-Null

  $row.Add_MouseLeftButtonDown({
    if ($_.ClickCount -ge 2) {
      Start-Process ([string]$service.Url)
    }
  })
  $row.Child = $grid
  return $row
}

function EmptyView {
  $border = New-Object System.Windows.Controls.Border
  $border.Height = 126
  $border.Margin = "0,8,0,10"
  $border.CornerRadius = "0"
  $border.Background = Brush "#FFFFFF"
  $border.BorderBrush = Brush "#DDE5EF"
  $border.BorderThickness = "1"
  $grid = New-Object System.Windows.Controls.Grid
  $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "56" }))
  $grid.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{ Width = "*" }))
  $dot = New-Object System.Windows.Shapes.Ellipse
  $dot.Width = 10; $dot.Height = 10; $dot.Fill = Brush "#009B63"; $dot.VerticalAlignment = "Center"; $dot.HorizontalAlignment = "Center"
  [System.Windows.Controls.Grid]::SetColumn($dot, 0); $grid.Children.Add($dot) | Out-Null
  $stack = New-Object System.Windows.Controls.StackPanel
  $stack.VerticalAlignment = "Center"
  $title = New-Object System.Windows.Controls.TextBlock
  $title.Text = T "EmptyTitle"; $title.FontSize = 16; $title.FontWeight = "Bold"; $title.Foreground = Brush "#111827"
  $hint = New-Object System.Windows.Controls.TextBlock
  $hint.Text = T "EmptyHint"; $hint.FontSize = 13; $hint.Foreground = Brush "#64748B"; $hint.Margin = "0,8,0,0"; $hint.TextWrapping = "Wrap"
  $stack.Children.Add($title) | Out-Null; $stack.Children.Add($hint) | Out-Null
  [System.Windows.Controls.Grid]::SetColumn($stack, 1); $grid.Children.Add($stack) | Out-Null
  $border.Child = $grid
  return $border
}

function Apply-Language {
  $TitleText.Text = T "AppTitle"
  $SubtitleText.Text = T "Subtitle"
  $PinButton.Content = T "Pin"
  $ScanButton.Content = T "Scan"
  $LangButton.Content = if ($script:lang -eq "zh") { "$(Z '5Lit')  EN" } else { "ZH  EN" }
  $MonitoringText.Text = T "Monitoring"
  $AutoScanText.Text = T "AutoScan"
  $RunningText.Text = T "WebEntries"
  $LastUpdatedText.Text = T "LastUpdated"
  $HealthText.Text = if ($script:scanJob -and $script:scanJob.State -eq "Running") { T "Scanning" } else { T "Healthy" }
  $FooterText.Text = "$(T 'FooterScan')   |   $(T 'WebEntries') $($script:services.Count)"
  Render-Services
}

function Start-ScanJob {
  if ($script:scanJob -and $script:scanJob.State -eq "Running") { return }
  if ($script:scanJob) { Remove-Job $script:scanJob -Force | Out-Null; $script:scanJob = $null }
  $script:lastScanStarted = Get-Date
  $HealthText.Text = T "Scanning"
  $script:scanJob = Start-Job -ScriptBlock {
    function Get-Title([string]$html) {
      $match = [regex]::Match($html, "<title[^>]*>([\s\S]*?)</title>", "IgnoreCase")
      if (-not $match.Success) { return "" }
      return (($match.Groups[1].Value -replace "\s+", " ").Trim())
    }
    function Get-Framework([string]$text) {
      $lower = $text.ToLowerInvariant()
      if ($lower.Contains("/@vite/client") -or $lower.Contains("vite")) { return "Vite" }
      if ($lower.Contains("__next") -or $lower.Contains("next.js")) { return "Next.js" }
      if ($lower.Contains("react-refresh") -or $lower.Contains("react-dom")) { return "React" }
      if ($lower.Contains("__vue") -or $lower.Contains("vue.global")) { return "Vue" }
      if ($lower.Contains("__nuxt") -or $lower.Contains("nuxt")) { return "Nuxt" }
      if ($lower.Contains("svelte")) { return "Svelte" }
      if ($lower.Contains("ng-version") -or $lower.Contains("angular")) { return "Angular" }
      if ($lower.Contains("astro-island") -or $lower.Contains("astro")) { return "Astro" }
      return "HTML"
    }
    function Fetch-Preview([string]$url) {
      try {
        $request = [System.Net.HttpWebRequest]::Create($url)
        $request.Method = "GET"
        $request.Timeout = 260
        $request.ReadWriteTimeout = 260
        $request.UserAgent = "LocalWebMonitor/4.0"
        $request.Accept = "text/html,application/xhtml+xml,application/json,*/*"
        $response = $request.GetResponse()
        $stream = $response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $body = $reader.ReadToEnd()
        $result = [pscustomobject]@{
          StatusCode = [int]$response.StatusCode
          ContentType = [string]$response.ContentType
          Body = $body
        }
        $reader.Dispose()
        $response.Dispose()
        return $result
      } catch {
        return $null
      }
    }

    $commonPorts = @(3000,3001,3002,3003,3004,3005,3333,4000,4200,4321,5000,5173,5174,5175,5176,5177,5178,5179,5180,6006,7000,8000,8080,8081,8888,9000,10000)
    $connections = @(Get-NetTCPConnection -State Listen | Where-Object { $_.LocalPort -ge 1000 -and $_.LocalPort -le 65535 })
    $portProcessNames = @{}
    foreach ($connection in $connections) {
      try {
        $process = Get-Process -Id $connection.OwningProcess -ErrorAction SilentlyContinue
        $portProcessNames[[int]$connection.LocalPort] = ([string]$process.ProcessName).ToLowerInvariant()
      } catch {}
    }
    $commonListening = @($connections | Where-Object { $commonPorts -contains [int]$_.LocalPort } | Select-Object -ExpandProperty LocalPort)
    $devProcessPorts = @()
    foreach ($connection in $connections) {
      try {
        $process = Get-Process -Id $connection.OwningProcess -ErrorAction SilentlyContinue
        $name = ([string]$process.ProcessName).ToLowerInvariant()
        if ($name -match "node|bun|deno|npm|pnpm|yarn|vite|next|python|ruby") {
          $devProcessPorts += [int]$connection.LocalPort
        }
      } catch {}
    }
    $allListening = @($connections | Select-Object -ExpandProperty LocalPort -Unique)
    $priorityPorts = @($commonListening + $devProcessPorts | Sort-Object -Unique)
    $otherPorts = @($allListening | Where-Object { $priorityPorts -notcontains [int]$_ } | Sort-Object)
    $ports = @($priorityPorts + $otherPorts | Sort-Object -Unique | Select-Object -First 260)
    $found = @()
    $warm = @()
    foreach ($port in $ports) {
      $url = "http://127.0.0.1:$port/"
      try {
        $response = Fetch-Preview $url
        if (-not $response) { continue }
        $contentType = [string]$response.ContentType
        $body = [string]$response.Body
        $lowerContentType = $contentType.ToLowerInvariant()
        $looksLikeHtml = $lowerContentType.Contains("text/html") -or $body.ToLowerInvariant().Contains("<html")
        $looksLikeJson = $lowerContentType.Contains("application/json") -or $body.TrimStart().StartsWith("{") -or $body.TrimStart().StartsWith("[")
        if (($looksLikeHtml -or $looksLikeJson) -and [int]$response.StatusCode -lt 500) {
          $title = Get-Title $body
          $lowerTitle = ([string]$title).ToLowerInvariant()
          $processName = [string]$portProcessNames[[int]$port]
          if ($lowerTitle.Contains("content shell remote debugging")) { continue }
          if ($lowerTitle -eq "antigravity") { continue }
          if ($processName -in @("antigravity", "language_server")) { continue }
          $preview = if ($body.Length -gt 12000) { $body.Substring(0, 12000) } else { $body }
          $framework = if ($looksLikeJson) { "API" } else { Get-Framework ($contentType + " " + $preview) }
          if ([string]::IsNullOrWhiteSpace($title)) { $title = "$framework $port" }
          $kind = if ($looksLikeJson) { "api" } else { "web" }
          $found += [pscustomobject]@{ Port = $port; Url = $url; Title = $title; Framework = $framework; Status = [int]$response.StatusCode; Kind = $kind }
        } elseif ([int]$response.StatusCode -ge 500) {
          $warm += [pscustomobject]@{ Port = $port; Url = $url; Title = "HTTP $($response.StatusCode)"; Framework = "HTTP"; Status = [int]$response.StatusCode }
        }
      } catch {}
    }
    [pscustomobject]@{ Ports = $ports.Count; Running = @($found); Starting = @($warm) } | ConvertTo-Json -Depth 5 -Compress
  }
}

function Render-Services {
  if (-not $ServiceStack) { return }
  try {
    $ServiceStack.Children.Clear()
    $running = if ($null -eq $script:services) { @() } else { @($script:services) }
    $ServiceStack.Children.Add((SectionHeader (T "WebEntries") $running.Count "#009B63" "#E8F7F0")) | Out-Null
    if ($running.Count -eq 0) {
      $ServiceStack.Children.Add((EmptyView)) | Out-Null
    } else {
      foreach ($service in $running) {
        try { $ServiceStack.Children.Add((RowView $service "running")) | Out-Null } catch {}
      }
    }
  } catch {
  }
}

function Poll-ScanJob {
  if ($script:scanJob -and $script:scanJob.State -ne "Running") {
    $raw = Receive-Job $script:scanJob
    Remove-Job $script:scanJob -Force | Out-Null
    $script:scanJob = $null
    $result = ($raw | Select-Object -Last 1) | ConvertFrom-Json
    $script:services = @()
    if ($null -ne $result.Running) { $script:services = @($result.Running) }
    $script:startingServices = @()
    if ($null -ne $result.Starting) { $script:startingServices = @($result.Starting) }
    $script:lastPortCount = [int]$result.Ports
    $script:lastUpdated = Get-Date
    $RunningCountText.Text = [string]$script:services.Count
    $LastUpdatedValue.Text = $script:lastUpdated.ToString("HH:mm:ss")
    $HealthText.Text = T "Healthy"
    $FooterText.Text = "$(T 'FooterScan')   |   $(T 'WebEntries') $($script:services.Count)"
    Render-Services
  }
  $age = ((Get-Date) - $script:lastScanStarted).TotalMilliseconds
  if (-not $script:scanJob -and $age -ge $script:scanIntervalMs) { Start-ScanJob }
}

function Try-DragWindow($eventArgs) {
  if ($eventArgs.ChangedButton -eq [System.Windows.Input.MouseButton]::Left) {
    $node = $eventArgs.OriginalSource
    while ($node) {
      if ($node -is [System.Windows.Controls.Button]) { return }
      if ($node -is [System.Windows.Controls.TextBlock]) {
        if ($node.Name -in @("PinButton", "ScanButton", "LangButton")) { return }
      }
      if ($node -is [System.Windows.FrameworkElement]) {
        if ($node.Name -in @("PinButton", "ScanButton", "LangButton")) { return }
      }
      try { $node = [System.Windows.Media.VisualTreeHelper]::GetParent($node) } catch { $node = $null }
    }
    try { $window.DragMove() } catch {}
  }
}

$Header.Add_MouseLeftButtonDown({ param($sender, $eventArgs) Try-DragWindow $eventArgs })
$Chrome.Add_MouseLeftButtonDown({ param($sender, $eventArgs) Try-DragWindow $eventArgs })
$MinButton.Add_Click({ $window.WindowState = "Minimized" })
$CloseButton.Add_Click({ $window.Close() })
$PinButton.Add_MouseLeftButtonUp({
  $window.Topmost = -not $window.Topmost
  $PinButton.Foreground = if ($window.Topmost) { Brush "#009B63" } else { Brush "#64748B" }
})
$ScanButton.Add_MouseLeftButtonUp({ Start-ScanJob })
function Switch-Language {
  $script:lang = if ($script:lang -eq "zh") { "en" } else { "zh" }
  Apply-Language
}

$LangButton.Add_MouseLeftButtonUp({ Switch-Language })

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(500)
$timer.Add_Tick({ Poll-ScanJob })
$timer.Start()

$window.Add_Loaded({
  Apply-Language
  Start-ScanJob
})

$window.Add_Closed({
  $timer.Stop()
  if ($script:scanJob) { Remove-Job $script:scanJob -Force | Out-Null }
  $mutex.ReleaseMutex()
  $mutex.Dispose()
})

$window.ShowDialog() | Out-Null
