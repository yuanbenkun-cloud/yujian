using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace SequenceAutoClicker
{
    internal static class Program
    {
        [DllImport("user32.dll")]
        private static extern bool SetProcessDPIAware();

        [STAThread]
        private static void Main()
        {
            try { SetProcessDPIAware(); } catch { }
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            bool created;
            using (Mutex mutex = new Mutex(true, "SequenceAutoClicker.SingleInstance", out created))
            {
                if (!created)
                {
                    MessageBox.Show("顺序连点器已经在运行。", "提示", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    return;
                }
                Application.Run(new MainForm());
            }
        }
    }

    internal sealed class ClickPoint
    {
        public int X;
        public int Y;

        public ClickPoint(int x, int y)
        {
            X = x;
            Y = y;
        }

        public override string ToString()
        {
            return string.Format("X: {0}    Y: {1}", X, Y);
        }
    }

    internal sealed class MainForm : Form
    {
        private const int WM_HOTKEY = 0x0312;
        private const int HOTKEY_TOGGLE = 6001;
        private const int HOTKEY_CAPTURE = 6002;
        private const int HOTKEY_ESCAPE = 6003;
        private const uint INPUT_MOUSE = 0;
        private const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
        private const uint MOUSEEVENTF_LEFTUP = 0x0004;

        [StructLayout(LayoutKind.Sequential)]
        private struct MOUSEINPUT
        {
            public int dx;
            public int dy;
            public uint mouseData;
            public uint dwFlags;
            public uint time;
            public UIntPtr dwExtraInfo;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct INPUT
        {
            public uint type;
            public MOUSEINPUT mi;
        }

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint modifiers, uint key);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

        [DllImport("user32.dll")]
        private static extern bool SetCursorPos(int x, int y);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern uint SendInput(uint count, INPUT[] inputs, int size);

        private readonly List<ClickPoint> points = new List<ClickPoint>();
        private readonly ListBox pointList = new ListBox();
        private readonly NumericUpDown rateBox = new NumericUpDown();
        private readonly Button startButton = new Button();
        private readonly Button layoutButton = new Button();
        private readonly Label statusLabel = new Label();
        private readonly Label countLabel = new Label();
        private readonly ManualResetEvent stopEvent = new ManualResetEvent(false);
        private readonly string configPath;

        private volatile bool running;
        private Thread clickThread;
        private bool hotkeysReady;
        private bool escapeRegistered;
        private Button addCurrentButton;
        private Button removeButton;
        private Button clearButton;
        private Button upButton;
        private Button downButton;

        public MainForm()
        {
            configPath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
                "SequenceAutoClicker",
                "config.txt");

            Text = "顺序连点器";
            StartPosition = FormStartPosition.CenterScreen;
            MinimumSize = new Size(720, 560);
            Size = new Size(780, 600);
            BackColor = Color.FromArgb(247, 248, 250);
            Font = new Font("Microsoft YaHei UI", 9F, FontStyle.Regular, GraphicsUnit.Point);

            BuildUi();
            LoadConfig();
            RefreshPointList();
        }

        private void BuildUi()
        {
            Panel header = new Panel();
            header.Dock = DockStyle.Top;
            header.Height = 88;
            header.BackColor = Color.FromArgb(31, 35, 41);
            Controls.Add(header);

            Label title = new Label();
            title.Text = "顺序连点器";
            title.ForeColor = Color.White;
            title.Font = new Font("Microsoft YaHei UI", 20F, FontStyle.Bold);
            title.AutoSize = true;
            title.Location = new Point(24, 15);
            header.Controls.Add(title);

            Label subtitle = new Label();
            subtitle.Text = "按设定顺序循环点击 · F6 启动/停止 · F8 记录鼠标位置";
            subtitle.ForeColor = Color.FromArgb(205, 210, 218);
            subtitle.AutoSize = true;
            subtitle.Location = new Point(27, 57);
            header.Controls.Add(subtitle);

            Panel leftCard = MakeCard();
            leftCard.Location = new Point(20, 108);
            leftCard.Size = new Size(455, 425);
            leftCard.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
            Controls.Add(leftCard);

            Label listTitle = new Label();
            listTitle.Text = "点击点位";
            listTitle.Font = new Font(Font, FontStyle.Bold);
            listTitle.AutoSize = true;
            listTitle.Location = new Point(18, 16);
            leftCard.Controls.Add(listTitle);

            countLabel.AutoSize = true;
            countLabel.ForeColor = Color.FromArgb(107, 113, 124);
            countLabel.Location = new Point(90, 18);
            leftCard.Controls.Add(countLabel);

            pointList.Location = new Point(18, 45);
            pointList.Size = new Size(419, 290);
            pointList.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
            pointList.BorderStyle = BorderStyle.FixedSingle;
            pointList.Font = new Font("Consolas", 10F);
            pointList.IntegralHeight = false;
            leftCard.Controls.Add(pointList);

            upButton = MakeSmallButton("上移", 18);
            downButton = MakeSmallButton("下移", 101);
            removeButton = MakeSmallButton("删除", 184);
            clearButton = MakeSmallButton("清空", 267);
            upButton.Anchor = downButton.Anchor = removeButton.Anchor = clearButton.Anchor = AnchorStyles.Bottom | AnchorStyles.Left;
            upButton.Click += delegate { MoveSelected(-1); };
            downButton.Click += delegate { MoveSelected(1); };
            removeButton.Click += delegate { RemoveSelected(); };
            clearButton.Click += delegate { ClearPoints(); };
            leftCard.Controls.Add(upButton);
            leftCard.Controls.Add(downButton);
            leftCard.Controls.Add(removeButton);
            leftCard.Controls.Add(clearButton);

            Panel rightCard = MakeCard();
            rightCard.Location = new Point(495, 108);
            rightCard.Size = new Size(245, 425);
            rightCard.Anchor = AnchorStyles.Top | AnchorStyles.Bottom | AnchorStyles.Right;
            Controls.Add(rightCard);

            Label rateTitle = new Label();
            rateTitle.Text = "点击速率";
            rateTitle.Font = new Font(Font, FontStyle.Bold);
            rateTitle.AutoSize = true;
            rateTitle.Location = new Point(18, 16);
            rightCard.Controls.Add(rateTitle);

            rateBox.Minimum = 1;
            rateBox.Maximum = 100;
            rateBox.Value = 20;
            rateBox.Location = new Point(18, 45);
            rateBox.Size = new Size(128, 27);
            rateBox.Font = new Font("Microsoft YaHei UI", 11F, FontStyle.Bold);
            rateBox.ValueChanged += delegate { SaveConfig(); };
            rightCard.Controls.Add(rateBox);

            Label unit = new Label();
            unit.Text = "次/秒";
            unit.AutoSize = true;
            unit.Location = new Point(154, 51);
            rightCard.Controls.Add(unit);

            Label hint = new Label();
            hint.Text = "速率是所有点位合计的点击次数。\r\n例如 4 个点、20 次/秒，每轮约 0.2 秒。";
            hint.ForeColor = Color.FromArgb(107, 113, 124);
            hint.Location = new Point(18, 82);
            hint.Size = new Size(210, 53);
            rightCard.Controls.Add(hint);

            layoutButton.Text = "屏幕布点";
            layoutButton.Location = new Point(18, 150);
            layoutButton.Size = new Size(209, 42);
            layoutButton.BackColor = Color.FromArgb(255, 197, 61);
            layoutButton.FlatStyle = FlatStyle.Flat;
            layoutButton.FlatAppearance.BorderSize = 0;
            layoutButton.Font = new Font(Font, FontStyle.Bold);
            layoutButton.Click += delegate { OpenLayoutOverlay(); };
            rightCard.Controls.Add(layoutButton);

            addCurrentButton = new Button();
            addCurrentButton.Text = "记录当前位置（F8）";
            addCurrentButton.Location = new Point(18, 202);
            addCurrentButton.Size = new Size(209, 38);
            addCurrentButton.FlatStyle = FlatStyle.Flat;
            addCurrentButton.FlatAppearance.BorderColor = Color.FromArgb(210, 214, 221);
            addCurrentButton.Click += delegate { AddCursorPosition(); };
            rightCard.Controls.Add(addCurrentButton);

            startButton.Text = "开始点击（F6）";
            startButton.Location = new Point(18, 263);
            startButton.Size = new Size(209, 52);
            startButton.BackColor = Color.FromArgb(0, 181, 120);
            startButton.ForeColor = Color.White;
            startButton.FlatStyle = FlatStyle.Flat;
            startButton.FlatAppearance.BorderSize = 0;
            startButton.Font = new Font("Microsoft YaHei UI", 11F, FontStyle.Bold);
            startButton.Click += delegate { ToggleClicking(); };
            rightCard.Controls.Add(startButton);

            statusLabel.Text = "● 已停止";
            statusLabel.ForeColor = Color.FromArgb(107, 113, 124);
            statusLabel.Font = new Font(Font, FontStyle.Bold);
            statusLabel.AutoSize = true;
            statusLabel.Location = new Point(18, 330);
            rightCard.Controls.Add(statusLabel);

            Label safety = new Label();
            safety.Text = "运行时按 Esc 或 F6 可立即停止。\r\n关闭窗口也会立即停止。";
            safety.ForeColor = Color.FromArgb(229, 83, 75);
            safety.Location = new Point(18, 357);
            safety.Size = new Size(210, 48);
            rightCard.Controls.Add(safety);
        }

        private Panel MakeCard()
        {
            Panel panel = new Panel();
            panel.BackColor = Color.White;
            panel.BorderStyle = BorderStyle.FixedSingle;
            return panel;
        }

        private Button MakeSmallButton(string text, int x)
        {
            Button button = new Button();
            button.Text = text;
            button.Location = new Point(x, 352);
            button.Size = new Size(72, 36);
            button.FlatStyle = FlatStyle.Flat;
            button.FlatAppearance.BorderColor = Color.FromArgb(210, 214, 221);
            return button;
        }

        protected override void OnShown(EventArgs e)
        {
            base.OnShown(e);
            bool f6 = RegisterHotKey(Handle, HOTKEY_TOGGLE, 0, (uint)Keys.F6);
            bool f8 = RegisterHotKey(Handle, HOTKEY_CAPTURE, 0, (uint)Keys.F8);
            hotkeysReady = f6 && f8;
            if (!hotkeysReady)
            {
                statusLabel.Text = "● 热键注册失败，可使用窗口按钮";
                statusLabel.ForeColor = Color.FromArgb(229, 83, 75);
            }
        }

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == WM_HOTKEY)
            {
                int id = m.WParam.ToInt32();
                if (id == HOTKEY_TOGGLE) ToggleClicking();
                if (id == HOTKEY_CAPTURE && !running) AddCursorPosition();
                if (id == HOTKEY_ESCAPE && running) StopClicking();
            }
            base.WndProc(ref m);
        }

        private void OpenLayoutOverlay()
        {
            if (running) return;
            Hide();
            Thread.Sleep(180);
            using (LayoutOverlay overlay = new LayoutOverlay(points))
            {
                overlay.ShowDialog();
                points.Clear();
                points.AddRange(overlay.ResultPoints);
            }
            Show();
            Activate();
            RefreshPointList();
            SaveConfig();
        }

        private void AddCursorPosition()
        {
            if (running) return;
            Point p = Cursor.Position;
            points.Add(new ClickPoint(p.X, p.Y));
            RefreshPointList();
            pointList.SelectedIndex = points.Count - 1;
            SaveConfig();
        }

        private void MoveSelected(int direction)
        {
            if (running) return;
            int oldIndex = pointList.SelectedIndex;
            int newIndex = oldIndex + direction;
            if (oldIndex < 0 || newIndex < 0 || newIndex >= points.Count) return;
            ClickPoint item = points[oldIndex];
            points.RemoveAt(oldIndex);
            points.Insert(newIndex, item);
            RefreshPointList();
            pointList.SelectedIndex = newIndex;
            SaveConfig();
        }

        private void RemoveSelected()
        {
            if (running) return;
            int index = pointList.SelectedIndex;
            if (index < 0) return;
            points.RemoveAt(index);
            RefreshPointList();
            if (points.Count > 0) pointList.SelectedIndex = Math.Min(index, points.Count - 1);
            SaveConfig();
        }

        private void ClearPoints()
        {
            if (running || points.Count == 0) return;
            if (MessageBox.Show("确定清空全部点位吗？", "确认", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
            points.Clear();
            RefreshPointList();
            SaveConfig();
        }

        private void RefreshPointList()
        {
            pointList.BeginUpdate();
            pointList.Items.Clear();
            for (int i = 0; i < points.Count; i++)
            {
                pointList.Items.Add(string.Format("{0,2}.  {1}", i + 1, points[i]));
            }
            pointList.EndUpdate();
            countLabel.Text = string.Format("共 {0} 个", points.Count);
        }

        private void ToggleClicking()
        {
            if (running) StopClicking();
            else StartClicking();
        }

        private void StartClicking()
        {
            if (running) return;
            if (points.Count == 0)
            {
                MessageBox.Show("请先添加至少一个点击点位。", "没有点位", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }

            List<ClickPoint> snapshot = new List<ClickPoint>();
            foreach (ClickPoint p in points) snapshot.Add(new ClickPoint(p.X, p.Y));
            int rate = (int)rateBox.Value;

            running = true;
            stopEvent.Reset();
            escapeRegistered = RegisterHotKey(Handle, HOTKEY_ESCAPE, 0, (uint)Keys.Escape);
            SetEditingEnabled(false);
            startButton.Text = "停止点击（Esc / F6）";
            startButton.BackColor = Color.FromArgb(229, 83, 75);
            statusLabel.Text = "● 正在运行";
            statusLabel.ForeColor = Color.FromArgb(0, 181, 120);

            clickThread = new Thread(new ThreadStart(delegate { ClickLoop(snapshot, rate); }));
            clickThread.IsBackground = true;
            clickThread.Name = "AutoClickWorker";
            clickThread.Start();
        }

        private void StopClicking()
        {
            if (!running) return;
            running = false;
            stopEvent.Set();
            ReleaseEscapeHotkey();
            SetStoppedUi();
        }

        private void ReleaseEscapeHotkey()
        {
            if (!escapeRegistered) return;
            UnregisterHotKey(Handle, HOTKEY_ESCAPE);
            escapeRegistered = false;
        }

        private void SetStoppedUi()
        {
            if (InvokeRequired)
            {
                BeginInvoke(new Action(SetStoppedUi));
                return;
            }
            SetEditingEnabled(true);
            startButton.Text = "开始点击（F6）";
            startButton.BackColor = Color.FromArgb(0, 181, 120);
            statusLabel.Text = "● 已停止";
            statusLabel.ForeColor = Color.FromArgb(107, 113, 124);
        }

        private void SetEditingEnabled(bool enabled)
        {
            rateBox.Enabled = enabled;
            layoutButton.Enabled = enabled;
            addCurrentButton.Enabled = enabled;
            removeButton.Enabled = enabled;
            clearButton.Enabled = enabled;
            upButton.Enabled = enabled;
            downButton.Enabled = enabled;
        }

        private void ClickLoop(List<ClickPoint> snapshot, int rate)
        {
            try
            {
                long interval = Math.Max(1L, Stopwatch.Frequency / rate);
                long next = Stopwatch.GetTimestamp();
                int index = 0;

                while (running)
                {
                    ClickPoint p = snapshot[index];
                    SendLeftClick(p.X, p.Y);
                    index = (index + 1) % snapshot.Count;
                    next += interval;

                    while (running)
                    {
                        long now = Stopwatch.GetTimestamp();
                        long remaining = next - now;
                        if (remaining <= 0)
                        {
                            if (-remaining > interval * 2) next = now;
                            break;
                        }
                        int milliseconds = (int)(remaining * 1000L / Stopwatch.Frequency);
                        if (milliseconds > 2)
                        {
                            if (stopEvent.WaitOne(milliseconds - 1)) break;
                        }
                        else
                        {
                            Thread.SpinWait(80);
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                running = false;
                BeginInvoke(new Action(delegate
                {
                    SetStoppedUi();
                    MessageBox.Show("点击线程已停止：" + ex.Message, "运行错误", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }));
            }
        }

        private static void SendLeftClick(int x, int y)
        {
            SetCursorPos(x, y);
            INPUT[] inputs = new INPUT[2];
            inputs[0].type = INPUT_MOUSE;
            inputs[0].mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
            inputs[1].type = INPUT_MOUSE;
            inputs[1].mi.dwFlags = MOUSEEVENTF_LEFTUP;
            SendInput(2, inputs, Marshal.SizeOf(typeof(INPUT)));
        }

        private void LoadConfig()
        {
            try
            {
                if (!File.Exists(configPath)) return;
                string[] lines = File.ReadAllLines(configPath);
                foreach (string raw in lines)
                {
                    string line = raw.Trim();
                    if (line.StartsWith("rate="))
                    {
                        decimal value;
                        if (decimal.TryParse(line.Substring(5), out value))
                            rateBox.Value = Math.Max(rateBox.Minimum, Math.Min(rateBox.Maximum, value));
                    }
                    else if (line.StartsWith("point="))
                    {
                        string[] xy = line.Substring(6).Split(',');
                        int x, y;
                        if (xy.Length == 2 && int.TryParse(xy[0], out x) && int.TryParse(xy[1], out y))
                            points.Add(new ClickPoint(x, y));
                    }
                }
            }
            catch { }
        }

        private void SaveConfig()
        {
            try
            {
                string folder = Path.GetDirectoryName(configPath);
                if (!Directory.Exists(folder)) Directory.CreateDirectory(folder);
                List<string> lines = new List<string>();
                lines.Add("rate=" + rateBox.Value);
                foreach (ClickPoint p in points) lines.Add(string.Format("point={0},{1}", p.X, p.Y));
                File.WriteAllLines(configPath, lines.ToArray());
            }
            catch { }
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            running = false;
            stopEvent.Set();
            ReleaseEscapeHotkey();
            if (clickThread != null && clickThread.IsAlive) clickThread.Join(400);
            SaveConfig();
            if (hotkeysReady)
            {
                UnregisterHotKey(Handle, HOTKEY_TOGGLE);
                UnregisterHotKey(Handle, HOTKEY_CAPTURE);
            }
            stopEvent.Dispose();
            base.OnFormClosing(e);
        }
    }

    internal sealed class LayoutOverlay : Form
    {
        private readonly List<ClickPoint> workingPoints = new List<ClickPoint>();
        private readonly Rectangle virtualBounds;

        public List<ClickPoint> ResultPoints
        {
            get
            {
                List<ClickPoint> result = new List<ClickPoint>();
                foreach (ClickPoint p in workingPoints) result.Add(new ClickPoint(p.X, p.Y));
                return result;
            }
        }

        public LayoutOverlay(IEnumerable<ClickPoint> existing)
        {
            foreach (ClickPoint p in existing) workingPoints.Add(new ClickPoint(p.X, p.Y));
            virtualBounds = SystemInformation.VirtualScreen;

            FormBorderStyle = FormBorderStyle.None;
            StartPosition = FormStartPosition.Manual;
            Bounds = virtualBounds;
            BackColor = Color.Black;
            Opacity = 0.42;
            TopMost = true;
            ShowInTaskbar = false;
            KeyPreview = true;
            Cursor = Cursors.Cross;
            DoubleBuffered = true;
        }

        protected override void OnShown(EventArgs e)
        {
            base.OnShown(e);
            Activate();
            Focus();
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            base.OnMouseDown(e);
            if (e.Button == MouseButtons.Left)
            {
                workingPoints.Add(new ClickPoint(e.X + virtualBounds.X, e.Y + virtualBounds.Y));
                Invalidate();
            }
            else if (e.Button == MouseButtons.Right)
            {
                DialogResult = DialogResult.OK;
                Close();
            }
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Escape || e.KeyCode == Keys.Enter)
            {
                DialogResult = DialogResult.OK;
                Close();
                return;
            }
            if ((e.KeyCode == Keys.Back || e.KeyCode == Keys.Delete) && workingPoints.Count > 0)
            {
                workingPoints.RemoveAt(workingPoints.Count - 1);
                Invalidate();
            }
            base.OnKeyDown(e);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;

            using (Font titleFont = new Font("Microsoft YaHei UI", 15F, FontStyle.Bold))
            using (Font hintFont = new Font("Microsoft YaHei UI", 10F, FontStyle.Regular))
            using (Brush white = new SolidBrush(Color.White))
            {
                g.DrawString("布点模式：依次左键添加点位", titleFont, white, 24, 20);
                g.DrawString("右键 / Enter / Esc 完成，Backspace 删除最后一个点", hintFont, white, 27, 56);
            }

            for (int i = 0; i < workingPoints.Count; i++)
            {
                float x = workingPoints[i].X - virtualBounds.X;
                float y = workingPoints[i].Y - virtualBounds.Y;
                RectangleF circle = new RectangleF(x - 18, y - 18, 36, 36);
                using (Brush fill = new SolidBrush(Color.FromArgb(255, 197, 61)))
                using (Pen outline = new Pen(Color.FromArgb(31, 35, 41), 3F))
                using (Font numberFont = new Font("Microsoft YaHei UI", 10F, FontStyle.Bold))
                using (StringFormat format = new StringFormat())
                {
                    format.Alignment = StringAlignment.Center;
                    format.LineAlignment = StringAlignment.Center;
                    g.FillEllipse(fill, circle);
                    g.DrawEllipse(outline, circle);
                    g.DrawString((i + 1).ToString(), numberFont, Brushes.Black, circle, format);
                }
            }
        }
    }
}
