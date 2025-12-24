namespace Loupedeck.ReaperHapticPlugin
{
    using System;
    using System.Collections.Concurrent;
    using System.Threading;

    /// <summary>
    /// Manages haptic event triggering with debouncing to prevent rapid-fire feedback.
    /// </summary>
    public class HapticEventManager
    {
        // Event name constants matching YAML configuration
        public const string EventSnap = "snap";
        public const string EventClip = "clip";
        public const string EventRecordStart = "recordStart";
        public const string EventRecordStop = "recordStop";
        public const string EventRenderComplete = "renderComplete";
        public const string EventMarkerCrossed = "markerCrossed";
        public const string EventItemAligned = "itemAligned";
        public const string EventPlayStart = "playStart";
        public const string EventPlayStop = "playStop";

        private readonly Plugin _plugin;
        private readonly ConcurrentDictionary<string, long> _lastTriggerTimes = new();

        // Debounce intervals in milliseconds
        private readonly ConcurrentDictionary<string, int> _debounceIntervals = new()
        {
            [EventSnap] = 80,           // Quick feedback for precise snapping
            [EventClip] = 200,          // Avoid spam during sustained clipping
            [EventRecordStart] = 500,   // Once per record start
            [EventRecordStop] = 500,    // Once per record stop
            [EventRenderComplete] = 1000, // Once per render
            [EventMarkerCrossed] = 150, // Allow frequent but not spammy
            [EventItemAligned] = 100,   // Quick alignment feedback
            [EventPlayStart] = 500,     // Once per play start
            [EventPlayStop] = 500       // Once per play stop
        };

        public HapticEventManager(Plugin plugin)
        {
            _plugin = plugin ?? throw new ArgumentNullException(nameof(plugin));
        }

        /// <summary>
        /// Registers all haptic events with the plugin.
        /// </summary>
        public void RegisterEvents()
        {
            RegisterEvent(EventSnap, "Snap", "Triggered when an item snaps to grid, marker, or another item");
            RegisterEvent(EventClip, "Clip Detected", "Triggered when audio exceeds 0dB");
            RegisterEvent(EventRecordStart, "Record Start", "Triggered when recording begins");
            RegisterEvent(EventRecordStop, "Record Stop", "Triggered when recording ends");
            RegisterEvent(EventRenderComplete, "Render Complete", "Triggered when rendering finishes");
            RegisterEvent(EventMarkerCrossed, "Marker Crossed", "Triggered when playhead crosses a marker");
            RegisterEvent(EventItemAligned, "Item Aligned", "Triggered when items become aligned");
            RegisterEvent(EventPlayStart, "Play Start", "Triggered when playback begins");
            RegisterEvent(EventPlayStop, "Play Stop", "Triggered when playback stops");

            PluginLog.Info("Haptic events registered");
        }

        private void RegisterEvent(string name, string displayName, string description)
        {
            _plugin.PluginEvents.AddEvent(name, displayName, description);
            PluginLog.Verbose($"Registered haptic event: {name}");
        }

        /// <summary>
        /// Triggers a haptic event with debouncing.
        /// </summary>
        public bool TriggerEvent(string eventName)
        {
            if (!_debounceIntervals.TryGetValue(eventName, out var debounceMs))
            {
                debounceMs = 100; // Default debounce
            }

            var nowTicks = DateTime.UtcNow.Ticks;
            var lastTicks = _lastTriggerTimes.GetOrAdd(eventName, 0);
            var elapsedMs = (nowTicks - lastTicks) / TimeSpan.TicksPerMillisecond;

            if (elapsedMs < debounceMs)
            {
                PluginLog.Verbose($"Debounced event: {eventName} (elapsed: {elapsedMs}ms, threshold: {debounceMs}ms)");
                return false;
            }

            // Update last trigger time
            _lastTriggerTimes[eventName] = nowTicks;

            _plugin.PluginEvents.RaiseEvent(eventName);
            PluginLog.Info($"Haptic event triggered: {eventName}");
            return true;
        }

        /// <summary>
        /// Sets a custom debounce interval for an event.
        /// </summary>
        public void SetDebounceInterval(string eventName, int milliseconds)
        {
            _debounceIntervals[eventName] = Math.Max(0, milliseconds);
            PluginLog.Verbose($"Set debounce for {eventName} to {milliseconds}ms");
        }

        /// <summary>
        /// Resets the debounce timer for an event, allowing immediate triggering.
        /// </summary>
        public void ResetDebounce(string eventName)
        {
            _lastTriggerTimes.TryRemove(eventName, out _);
        }

        /// <summary>
        /// Resets all debounce timers.
        /// </summary>
        public void ResetAllDebounce()
        {
            _lastTriggerTimes.Clear();
        }
    }
}
