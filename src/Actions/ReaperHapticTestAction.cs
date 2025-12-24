namespace Loupedeck.ReaperHapticPlugin
{
    using System;

    /// <summary>
    /// Test action for manually triggering haptic events.
    /// Can be assigned to a button for testing the haptic feedback.
    /// </summary>
    public class ReaperHapticTestAction : PluginDynamicCommand
    {
        private int _testEventIndex = 0;
        private string _reaperIconPath;

        private readonly string[] _testEvents = new[]
        {
            HapticEventManager.EventSnap,
            HapticEventManager.EventClip,
            HapticEventManager.EventRecordStart,
            HapticEventManager.EventRecordStop,
            HapticEventManager.EventRenderComplete,
            HapticEventManager.EventMarkerCrossed,
            HapticEventManager.EventItemAligned
        };

        private readonly string[] _eventLabels = new[]
        {
            "Snap",
            "Clip",
            "Rec Start",
            "Rec Stop",
            "Render",
            "Marker",
            "Align"
        };

        public ReaperHapticTestAction()
            : base(
                displayName: "Test Haptic",
                description: "Cycles through and triggers each haptic event type for testing",
                groupName: "REAPER Haptics")
        {
        }

        protected override bool OnLoad()
        {
            try
            {
                _reaperIconPath = PluginResources.FindFile("reaper.png");
            }
            catch
            {
                _reaperIconPath = null;
            }

            PluginLog.Info("ReaperHapticTestAction loaded");
            return true;
        }

        protected override void RunCommand(string actionParameter)
        {
            var eventName = _testEvents[_testEventIndex];

            this.Plugin.PluginEvents.RaiseEvent(eventName);
            PluginLog.Info($"Test haptic triggered: {eventName}");

            // Cycle to next event for next press
            _testEventIndex = (_testEventIndex + 1) % _testEvents.Length;

            // Update the button image to show which event is next
            this.ActionImageChanged();
        }

        protected override BitmapImage GetCommandImage(string actionParameter, PluginImageSize imageSize)
        {
            var builder = new BitmapBuilder(imageSize);

            // Draw background
            builder.Clear(new BitmapColor(40, 40, 45));

            // Try to draw the REAPER icon
            if (_reaperIconPath != null)
            {
                try
                {
                    var icon = PluginResources.ReadImage(_reaperIconPath);
                    var iconSize = imageSize == PluginImageSize.Width60 ? 30 : 40;
                    var x = (builder.Width - iconSize) / 2;
                    builder.DrawImage(icon, x, 5, iconSize, iconSize);
                }
                catch
                {
                    // Ignore icon drawing errors
                }
            }

            // Draw text showing next event
            var nextLabel = _eventLabels[_testEventIndex];
            builder.DrawText(nextLabel, 0, builder.Height - 25, builder.Width, 20,
                new BitmapColor(255, 255, 255), imageSize == PluginImageSize.Width60 ? 10 : 12);

            return builder.ToImage();
        }

        protected override string GetCommandDisplayName(string actionParameter, PluginImageSize imageSize) =>
            "Test\nHaptic";
    }
}
