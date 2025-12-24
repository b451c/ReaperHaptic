namespace Loupedeck.ReaperHapticPlugin
{
    using System;

    public class ReaperHapticApplication : ClientApplication
    {
        public ReaperHapticApplication()
        {
        }

        protected override string GetProcessName() => "REAPER";

        protected override string GetBundleName() => "com.cockos.reaper";
    }
}
