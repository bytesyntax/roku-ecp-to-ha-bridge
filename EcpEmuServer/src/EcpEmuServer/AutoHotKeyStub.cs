namespace EcpEmuServer
{
    /// <summary>
    /// Stub implementation for non-Windows platforms.
    /// The real implementation uses AutoHotkey.Interop and is compiled only on Windows.
    /// </summary>
    public static class AutoHotKey
    {
        public static void SendRawCommand(string scancode)
        {
            // Intentionally no-op. On non-Windows platforms, RuleManager already blocks
            // AutoHotKey actions via RuntimeInformation.IsOSPlatform(OSPlatform.Windows).
        }
    }
}