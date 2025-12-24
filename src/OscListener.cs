namespace Loupedeck.ReaperHapticPlugin
{
    using System;
    using System.Net;
    using System.Threading;
    using System.Threading.Tasks;
    using Rug.Osc;

    /// <summary>
    /// Listens for OSC messages from REAPER on a specified UDP port.
    /// </summary>
    public class OscListener : IDisposable
    {
        private readonly int _port;
        private OscReceiver _receiver;
        private CancellationTokenSource _cts;
        private Task _listenTask;

        // Events for different REAPER actions
        public event Action OnSnapDetected;
        public event Action<float> OnClipDetected;
        public event Action OnRecordStart;
        public event Action OnRecordStop;
        public event Action OnRenderComplete;
        public event Action<int> OnMarkerCrossed;
        public event Action OnItemAligned;
        public event Action OnPlayStart;
        public event Action OnPlayStop;

        public OscListener(int port = 9000)
        {
            _port = port;
        }

        public void Start()
        {
            try
            {
                _receiver = new OscReceiver(_port);
                _receiver.Connect();
                _cts = new CancellationTokenSource();

                _listenTask = Task.Run(() => ListenLoop(_cts.Token));

                PluginLog.Info($"OSC listener started on port {_port}");
            }
            catch (Exception ex)
            {
                PluginLog.Error(ex, $"Failed to start OSC listener on port {_port}");
                throw;
            }
        }

        private void ListenLoop(CancellationToken token)
        {
            while (!token.IsCancellationRequested)
            {
                try
                {
                    if (_receiver.State != OscSocketState.Connected)
                    {
                        Thread.Sleep(100);
                        continue;
                    }

                    // Try to receive with timeout
                    var packet = _receiver.Receive();

                    if (packet is OscMessage message)
                    {
                        ProcessMessage(message);
                    }
                    else if (packet is OscBundle bundle)
                    {
                        foreach (var item in bundle)
                        {
                            if (item is OscMessage bundledMessage)
                            {
                                ProcessMessage(bundledMessage);
                            }
                        }
                    }
                }
                catch (Exception ex) when (ex.GetType().Name.Contains("Socket") || ex is ObjectDisposedException)
                {
                    // Socket was closed, exit gracefully
                    break;
                }
                catch (Exception ex)
                {
                    if (!token.IsCancellationRequested)
                    {
                        PluginLog.Error(ex, "Error receiving OSC message");
                    }
                }
            }
        }

        private void ProcessMessage(OscMessage message)
        {
            var address = message.Address;

            PluginLog.Verbose($"OSC received: {address}");

            try
            {
                switch (address)
                {
                    case "/reaper/snap":
                        OnSnapDetected?.Invoke();
                        break;

                    case "/reaper/clip":
                        var peakDb = message.Count > 0 ? Convert.ToSingle(message[0]) : 0f;
                        OnClipDetected?.Invoke(peakDb);
                        break;

                    case "/reaper/record/start":
                        OnRecordStart?.Invoke();
                        break;

                    case "/reaper/record/stop":
                        OnRecordStop?.Invoke();
                        break;

                    case "/reaper/render/complete":
                        OnRenderComplete?.Invoke();
                        break;

                    case "/reaper/marker":
                        var markerIndex = message.Count > 0 ? Convert.ToInt32(message[0]) : 0;
                        OnMarkerCrossed?.Invoke(markerIndex);
                        break;

                    case "/reaper/align":
                        OnItemAligned?.Invoke();
                        break;

                    case "/reaper/play/start":
                        OnPlayStart?.Invoke();
                        break;

                    case "/reaper/play/stop":
                        OnPlayStop?.Invoke();
                        break;

                    default:
                        // Check for wildcard patterns
                        if (address.StartsWith("/reaper/"))
                        {
                            PluginLog.Verbose($"Unhandled REAPER OSC message: {address}");
                        }
                        break;
                }
            }
            catch (Exception ex)
            {
                PluginLog.Error(ex, $"Error processing OSC message: {address}");
            }
        }

        public void Stop()
        {
            try
            {
                _cts?.Cancel();

                if (_receiver != null && _receiver.State == OscSocketState.Connected)
                {
                    _receiver.Close();
                }

                _listenTask?.Wait(TimeSpan.FromSeconds(2));

                PluginLog.Info("OSC listener stopped");
            }
            catch (Exception ex)
            {
                PluginLog.Error(ex, "Error stopping OSC listener");
            }
        }

        public void Dispose()
        {
            Stop();
            _receiver?.Dispose();
            _cts?.Dispose();
        }
    }
}
