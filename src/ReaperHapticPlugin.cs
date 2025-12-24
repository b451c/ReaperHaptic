namespace Loupedeck.ReaperHapticPlugin
{
    using System;

    /// <summary>
    /// ReaperHaptic Plugin - Provides haptic feedback for REAPER DAW events.
    /// Listens for OSC messages from REAPER and triggers MX Master 4 haptics.
    /// </summary>
    public class ReaperHapticPlugin : Plugin
    {
        private OscListener _oscListener;
        private HapticEventManager _hapticManager;

        private const int DefaultOscPort = 9000;

        // Gets a value indicating whether this is an API-only plugin.
        public override bool UsesApplicationApiOnly => true;

        // Gets a value indicating whether this is a Universal plugin or an Application plugin.
        public override bool HasNoApplication => true;

        // Initializes a new instance of the plugin class.
        public ReaperHapticPlugin()
        {
            // Initialize the plugin log.
            PluginLog.Init(this.Log);

            // Initialize the plugin resources.
            PluginResources.Init(this.Assembly);
        }

        // This method is called when the plugin is loaded.
        public override void Load()
        {
            try
            {
                PluginLog.Info("ReaperHaptic plugin loading...");

                // Initialize haptic event manager
                _hapticManager = new HapticEventManager(this);
                _hapticManager.RegisterEvents();

                // Initialize and start OSC listener
                _oscListener = new OscListener(DefaultOscPort);
                WireOscEvents();
                _oscListener.Start();

                PluginLog.Info("ReaperHaptic plugin loaded successfully");
            }
            catch (Exception ex)
            {
                PluginLog.Error(ex, "Failed to load ReaperHaptic plugin");
            }
        }

        private void WireOscEvents()
        {
            _oscListener.OnSnapDetected += () => _hapticManager.TriggerEvent(HapticEventManager.EventSnap);

            _oscListener.OnClipDetected += (peakDb) =>
            {
                PluginLog.Verbose($"Clip detected at {peakDb:F1}dB");
                _hapticManager.TriggerEvent(HapticEventManager.EventClip);
            };

            _oscListener.OnRecordStart += () =>
            {
                _hapticManager.ResetDebounce(HapticEventManager.EventRecordStart);
                _hapticManager.TriggerEvent(HapticEventManager.EventRecordStart);
            };

            _oscListener.OnRecordStop += () =>
            {
                _hapticManager.ResetDebounce(HapticEventManager.EventRecordStop);
                _hapticManager.TriggerEvent(HapticEventManager.EventRecordStop);
            };

            _oscListener.OnRenderComplete += () =>
            {
                _hapticManager.ResetDebounce(HapticEventManager.EventRenderComplete);
                _hapticManager.TriggerEvent(HapticEventManager.EventRenderComplete);
            };

            _oscListener.OnMarkerCrossed += (index) =>
            {
                PluginLog.Verbose($"Marker {index} crossed");
                _hapticManager.TriggerEvent(HapticEventManager.EventMarkerCrossed);
            };

            _oscListener.OnItemAligned += () => _hapticManager.TriggerEvent(HapticEventManager.EventItemAligned);

            _oscListener.OnPlayStart += () =>
            {
                _hapticManager.ResetDebounce(HapticEventManager.EventPlayStart);
                _hapticManager.TriggerEvent(HapticEventManager.EventPlayStart);
            };

            _oscListener.OnPlayStop += () =>
            {
                _hapticManager.ResetDebounce(HapticEventManager.EventPlayStop);
                _hapticManager.TriggerEvent(HapticEventManager.EventPlayStop);
            };
        }

        // This method is called when the plugin is unloaded.
        public override void Unload()
        {
            try
            {
                PluginLog.Info("ReaperHaptic plugin unloading...");

                _oscListener?.Stop();
                _oscListener?.Dispose();
                _oscListener = null;

                _hapticManager = null;

                PluginLog.Info("ReaperHaptic plugin unloaded");
            }
            catch (Exception ex)
            {
                PluginLog.Error(ex, "Error unloading ReaperHaptic plugin");
            }
        }
    }
}
