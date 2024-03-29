/***************************************************************************
 *                                  Main.cs
 *                            -------------------
 *   begin                : May 1, 2002
 *   copyright            : (C) The RunUO Software Team
 *   email                : info@runuo.com
 *
 *   $Id: Main.cs 521 2010-06-17 07:11:43Z mark $
 *
 ***************************************************************************/

/***************************************************************************
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation; either version 2 of the License, or
 *   (at your option) any later version.
 *
 ***************************************************************************/

using Server;
using Server.Accounting;
using Server.Gumps;
using Server.Network;

namespace Server
{
	public delegate void Slice();

	public static class Core
	{
		private static bool m_crashed;
		private static Thread timer_thread;
		private static string m_base_directory;
		private static string m_exe_path;
		private static List<string> m_DataDirectories = new List<string>();
		private static Assembly m_Assembly;
		private static Process m_process;
		private static Thread m_thread;
		private static bool m_service;
		private static MultiTextWriter m_MultiConOut;

		private static MessagePump m_MessagePump;

		public static MessagePump MessagePump
		{
			get { return m_MessagePump; }
			set { m_MessagePump = value; }
		}

		public static Slice Slice;

		public static bool Service { get { return m_service; } }
		public static List<string> DataDirectories { get { return m_DataDirectories; } }
		public static Assembly Assembly { get { return m_Assembly; } set { m_Assembly = value; } }
		public static Version Version { get { return m_Assembly.GetName().Version; } }
		public static Process Process { get { return m_process; } }
		public static Thread Thread { get { return m_thread; } }
		public static MultiTextWriter MultiConsoleOut { get { return m_MultiConOut; } }

		public static readonly bool Is64Bit = (IntPtr.Size == 8);
        //TODO: Upon public release of .NET 4.0, use Environment.Is64BitOperatingSystem/Process

		private static bool m_multi_processor;
		private static int m_processor_count;

		public static bool MultiProcessor { get { return m_multi_processor; } }
		public static int ProcessorCount { get { return m_processor_count; } }

		private static bool m_Unix;

		public static bool Unix { get { return m_Unix; } }

		public static string FindDataFile( string path )
		{
			if( m_DataDirectories.Count == 0 )
			{
				throw new InvalidOperationException( "Attempted to FindDataFile before DataDirectories list has been filled." );
			}

			string fullPath = null;

			for( int i = 0; i < m_DataDirectories.Count; ++i )
			{
				fullPath = Path.Combine( m_DataDirectories[i], path );

				if( File.Exists( fullPath ) )
				{
					break;
				}

				fullPath = null;
			}

			return fullPath;
		}

		public static string FindDataFile( string format, params object[] args )
		{
			return FindDataFile( String.Format( format, args ) );
		}

		#region Expansions

		private static Expansion m_expansion;
		public static Expansion expansion
		{
			get { return m_expansion; }
			set { m_expansion = value; }
		}

		public static bool T2A
		{
			get { return m_expansion >= Expansion.T2A; }
		}

		public static bool UOR
		{
			get { return m_expansion >= Expansion.UOR; }
		}

		public static bool UOTD
		{
			get { return m_expansion >= Expansion.UOTD; }
		}

		public static bool LBR
		{
			get { return m_expansion >= Expansion.LBR; }
		}

		public static bool AOS
		{
			get { return m_expansion >= Expansion.AOS; }
		}

		public static bool SE
		{
			get { return m_expansion >= Expansion.SE; }
		}

		public static bool ML
		{
			get { return m_expansion >= Expansion.ML; }
		}

		public static bool SA
		{
			get { return m_expansion >= Expansion.SA; }
		}

		#endregion

		public static string exe_path
		{
			get
			{
				if( m_exe_path == null )
				{
					m_exe_path = Assembly.Location;
					//m_exe_path = Process.GetCurrentProcess().MainModule.FileName;
				}

				return m_exe_path;
			}
		}

		public static string base_directory
		{
			get
			{
				if( m_base_directory == null )
				{
					try
					{
						m_base_directory = exe_path;

						if( m_base_directory.Length > 0 )
						{
							m_base_directory = Path.GetDirectoryName( m_base_directory );
						}
					}
					catch
					{
						m_base_directory = "";
					}
				}

				return m_base_directory;
			}
		}

		private static void CurrentDomain_UnhandledException( object sender, UnhandledExceptionEventArgs e )
		{
			stdout.printf( e.IsTerminating ? "Error:" : "Warning:" );
			stdout.printf( e.ExceptionObject );

			if( e.IsTerminating )
			{
				m_crashed = true;

				bool close = false;

				try
				{
					CrashedEventArgs args = new CrashedEventArgs( e.ExceptionObject as Exception );

					EventSink.InvokeCrashed( args );

					close = args.Close;
				}
				catch
				{
				}

				if( !close && !m_service )
				{
					try
					{
						for( int i = 0; i < m_MessagePump.Listeners.Length; i++ )
						{
							m_MessagePump.Listeners[i].Dispose();
						}
					}
					catch
					{
					}

					if ( m_service )
					{
						stdout.printf( "This exception is fatal." );
					}
					else
					{
						stdout.printf( "This exception is fatal, press return to exit" );
						Console.ReadLine();
					}
				}

				m_closing = true;
			}
		}

		private enum ConsoleEventType
		{
			CTRL_C_EVENT,
			CTRL_BREAK_EVENT,
			CTRL_CLOSE_EVENT,
			CTRL_LOGOFF_EVENT=5,
			CTRL_SHUTDOWN_EVENT
		}

		private delegate bool ConsoleEventHandler( ConsoleEventType type );
		private static ConsoleEventHandler m_ConsoleEventHandler;

		[DllImport( "Kernel32" )]
		private static extern bool SetConsoleCtrlHandler( ConsoleEventHandler callback, bool add );

		private static bool OnConsoleEvent( ConsoleEventType type )
		{
			if( World.Saving || ( m_service && type == ConsoleEventType.CTRL_LOGOFF_EVENT ) )
				return true;

			Kill();

			return true;
		}

		private static void CurrentDomain_ProcessExit( object sender, EventArgs e )
		{
			HandleClosed();
		}

		private static bool m_closing;
		public static bool Closing { get { return m_closing; } }

		private static long m_CycleIndex;
		private static float[] m_CyclesPerSecond = new float[100];

		public static float CyclesPerSecond
		{
			get { return m_CyclesPerSecond[(m_CycleIndex - 1) % m_CyclesPerSecond.Length]; }
		}

		public static float AverageCPS
		{
			get
			{
				float t = 0.0f;
				int c = 0;

				for( int i = 0; i < m_CycleIndex && i < m_CyclesPerSecond.Length; ++i )
				{
					t += m_CyclesPerSecond[i];
					++c;
				}

				return (t / Math.Max( c, 1 ));
			}
		}

		public static void Kill()
		{
			Kill( false );
		}

		public static void Kill( bool restart )
		{
			HandleClosed();

			if ( restart )
			{
				Process.Start( exe_path, Arguments );
			}

			m_process.Kill();
		}

		private static void HandleClosed()
		{
			if( m_closing )
			{
				return;
			}

			m_closing = true;

			Console.Write( "Exiting..." );

			if( !m_crashed )
			{
				EventSink.InvokeShutdown( new ShutdownEventArgs() );
			}

			Timer.TimerThread.Set();

			stdout.printf( "done" );
		}

		private static AutoResetEvent m_Signal = new AutoResetEvent( true );
		public static void Set() { m_Signal.Set(); }

		public static void main( string[] args )
		{
			for( int i = 0; i < args.Length; ++i )
			{
				if ( Insensitive.Equals( args[i], "-service" ) )
				{
					m_service = true;
				}
			}

			try
			{
				if( m_service )
				{
					var logpath = File.new_for_path ("Logs");
					logpath.make_directory_with_parents (null);

					Console.SetOut( m_MultiConOut = new MultiTextWriter( new FileLogger( "Logs/Console.log" ) ) );
				}
				else
				{
					Console.SetOut( m_MultiConOut = new MultiTextWriter( Console.Out ) );
				}
			}
			catch
			{
			}

			m_thread = Thread.CurrentThread;
			m_process = Process.GetCurrentProcess();
			m_Assembly = Assembly.GetEntryAssembly();

			if( m_thread != null )
				m_thread.Name = "Core Thread";

			if( base_directory.Length > 0 )
				Directory.SetCurrentDirectory( base_directory );

			Timer.TimerThread ttObj = new Timer.TimerThread();
			timer_thread = new Thread( new ThreadStart( ttObj.TimerMain ) );
			timer_thread.Name = "Timer Thread";

			stdout.printf( "ValaUO - [code.google.com/p/valauo]" );

			string s = Arguments;

			if( s.Length > 0 )
				stdout.printf( "Core: Running with arguments: {0}", s );

			m_processor_count = Environment.ProcessorCount;

			if( m_processor_count > 1 )
			{
				m_multi_processor = true;
			}

			if( m_multi_processor || Is64Bit )
				stdout.printf( "Core: Optimizing for {0} {2}processor{1}", m_processor_count, m_processor_count == 1 ? "" : "s", Is64Bit ? "64-bit " : "" );

			int platform = (int)Environment.OSVersion.Platform;
			if( platform == 4 || platform == 128 ) { // MS 4, MONO 128
				m_Unix = true;
				stdout.printf( "Core: Unix environment detected" );
			}
			else {
				m_ConsoleEventHandler = new ConsoleEventHandler( OnConsoleEvent );
				SetConsoleCtrlHandler( m_ConsoleEventHandler, true );
			}

			if ( GCSettings.IsServerGC )
			{
				stdout.printf("Core: Server garbage collection mode enabled");
			}

			Region.Load();
			World.Load();

			MessagePump ms = m_MessagePump = new MessagePump();

			timer_thread.Start();

			for( int i = 0; i < Map.AllMaps.Count; ++i )
			{
				Map.AllMaps[i].Tiles.Force();
			}

			NetState.Initialize();

			EventSink.InvokeServerStarted();

			try
			{
				DateTime now, last = DateTime.Now;

				const int sampleInterval = 100;
				const float ticksPerSecond = (float)(TimeSpan.TicksPerSecond * sampleInterval);

				long sample = 0;

				while( m_Signal.WaitOne() )
				{
					Mobile.ProcessDeltaQueue();
					Item.ProcessDeltaQueue();

					Timer.Slice();
					m_MessagePump.Slice();

					NetState.FlushAll();
					NetState.ProcessDisposedQueue();

					if( Slice != null )
					{
						Slice();
					}

					if( (++sample % sampleInterval) == 0 )
					{
						now = DateTime.Now;
						m_CyclesPerSecond[m_CycleIndex++ % m_CyclesPerSecond.Length] = ticksPerSecond / (now.Ticks - last.Ticks);
						last = now;
					}
				}
			}
			catch( Exception e )
			{
				CurrentDomain_UnhandledException( null, new UnhandledExceptionEventArgs( e, true ) );
			}
		}

		public static string Arguments
		{
			get
			{
				StringBuilder sb = new StringBuilder();

				if( Core.Service )
				{
					Utility.Separate( sb, "-service", " " );
				}

				return sb.ToString();
			}
		}

		private static int m_GlobalMaxUpdateRange = 24;

		public static int GlobalMaxUpdateRange
		{
			get { return m_GlobalMaxUpdateRange; }
			set { m_GlobalMaxUpdateRange = value; }
		}

		private static int m_ItemCount, m_MobileCount;

		public static int ScriptItems { get { return m_ItemCount; } }
		public static int ScriptMobiles { get { return m_MobileCount; } }

		public static void VerifySerialization()
		{
			m_ItemCount = 0;
			m_MobileCount = 0;

			VerifySerialization( Assembly.GetCallingAssembly() );

			for( int a = 0; a < ScriptCompiler.Assemblies.Length; ++a )
				VerifySerialization( ScriptCompiler.Assemblies[a] );
		}

		private static void VerifySerialization( Assembly a )
		{
			if( a == null )
				return;

			Type[] ctorTypes = new Type[] { typeof( Serial ) };

			foreach( Type t in a.GetTypes() )
			{
				bool isItem = t.IsSubclassOf( typeof( Item ) );

				if( isItem || t.IsSubclassOf( typeof( Mobile ) ) )
				{
					if( isItem )
						++m_ItemCount;
					else
						++m_MobileCount;

					bool warned = false;

					try
					{

						/*
						if( isItem && t.IsPublic && !t.IsAbstract )
						{
							ConstructorInfo cInfo = t.GetConstructor( Type.EmptyTypes );
							if( cInfo == null )
							{
								if( !warned )
									stdout.printf( "Warning: {0}", t );

								warned = true;
								stdout.printf( "       - No zero paramater constructor" );
							}
						}
						*/

						if( t.GetConstructor( ctorTypes ) == null )
						{
							if( !warned )
								stdout.printf( "Warning: {0}", t );

							warned = true;
							stdout.printf( "       - No serialization constructor" );
						}

						if( t.GetMethod( "Serialize", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.DeclaredOnly ) == null )
						{
							if( !warned )
								stdout.printf( "Warning: {0}", t );

							warned = true;
							stdout.printf( "       - No Serialize() method" );
						}

						if( t.GetMethod( "Deserialize", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.DeclaredOnly ) == null )
						{
							if( !warned )
								stdout.printf( "Warning: {0}", t );

							warned = true;
							stdout.printf( "       - No Deserialize() method" );
						}

						if( warned )
							stdout.printf();
					}
					catch
					{
                        stdout.printf( "Warning: Exception in serialization verification of type {0}", t );
					}
				}
			}
		}
	}

	public class FileLogger : TextWriter, IDisposable
	{
		private string m_FileName;
		private bool m_NewLine;
		public const string DateFormat = "[MMMM dd hh:mm:ss.f tt]: ";

		public string FileName { get { return m_FileName; } }

		public FileLogger( string file )
			: this( file, false )
		{
		}

		public FileLogger( string file, bool append )
		{
			m_FileName = file;
			using( StreamWriter writer = new StreamWriter( new FileStream( m_FileName, append ? FileMode.Append : FileMode.Create, FileAccess.Write, FileShare.Read ) ) )
			{
				writer.WriteLine( ">>>Logging started on {0}.", DateTime.Now.ToString( "f" ) ); //f = Tuesday, April 10, 2001 3:51 PM
			}
			m_NewLine = true;
		}

		public override void Write( char ch )
		{
			using( StreamWriter writer = new StreamWriter( new FileStream( m_FileName, FileMode.Append, FileAccess.Write, FileShare.Read ) ) )
			{
				if( m_NewLine )
				{
					writer.Write( DateTime.Now.ToString( DateFormat ) );
					m_NewLine = false;
				}
				writer.Write( ch );
			}
		}

		public override void Write( string str )
		{
			using( StreamWriter writer = new StreamWriter( new FileStream( m_FileName, FileMode.Append, FileAccess.Write, FileShare.Read ) ) )
			{
				if( m_NewLine )
				{
					writer.Write( DateTime.Now.ToString( DateFormat ) );
					m_NewLine = false;
				}
				writer.Write( str );
			}
		}

		public override void WriteLine( string line )
		{
			using( StreamWriter writer = new StreamWriter( new FileStream( m_FileName, FileMode.Append, FileAccess.Write, FileShare.Read ) ) )
			{
				if( m_NewLine )
					writer.Write( DateTime.Now.ToString( DateFormat ) );
				writer.WriteLine( line );
				m_NewLine = true;
			}
		}

		public override System.Text.Encoding Encoding
		{
			get { return System.Text.Encoding.Default; }
		}
	}

	public class MultiTextWriter : TextWriter
	{
		private List<TextWriter> m_Streams;

		public MultiTextWriter( params TextWriter[] streams )
		{
			m_Streams = new List<TextWriter>( streams );

			if( m_Streams.Count < 0 )
				throw new ArgumentException( "You must specify at least one stream." );
		}

		public void Add( TextWriter tw )
		{
			m_Streams.Add( tw );
		}

		public void Remove( TextWriter tw )
		{
			m_Streams.Remove( tw );
		}

		public override void Write( char ch )
		{
			for( int i = 0; i < m_Streams.Count; i++ )
				m_Streams[i].Write( ch );
		}

		public override void WriteLine( string line )
		{
			for( int i = 0; i < m_Streams.Count; i++ )
				m_Streams[i].WriteLine( line );
		}

		public override void WriteLine( string line, params object[] args )
		{
			WriteLine( String.Format( line, args ) );
		}

		public override Encoding Encoding
		{
			get { return Encoding.Default; }
		}
	}
}