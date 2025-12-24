namespace Loupedeck.ReaperHapticPlugin
{
    using System;

    internal static class PluginLog
    {
        private static PluginLogFile _log;

        public static void Init(PluginLogFile log) => _log = log;

        public static void Verbose(string message) => _log?.Verbose(message);
        public static void Info(string message) => _log?.Info(message);
        public static void Warning(string message) => _log?.Warning(message);
        public static void Error(string message) => _log?.Error(message);
        public static void Error(Exception ex, string message) => _log?.Error(ex, message);
    }
}
