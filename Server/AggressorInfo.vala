/***************************************************************************
 *                              AggressorInfo.cs
 *                            -------------------
 *   begin                : May 1, 2002
 *   copyright            : (C) The RunUO Software Team
 *   email                : info@runuo.com
 *
 *   $Id: AggressorInfo.cs 4 2006-06-15 04:28:39Z mark $
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
using Gee;

namespace Server
{
	public class AggressorInfo
	{
		private Mobile m_attacker;
		private Mobile m_defender;
		private DateTime m_last_combat_time;
		private bool m_can_report_murder;
		private bool m_reported;
		private bool m_criminal_aggression;

		private bool m_queued;

		private static PriorityQueue<AggressorInfo> m_pool = new PriorityQueue<AggressorInfo>();

		public static AggressorInfo create( Mobile attacker, Mobile defender, bool criminal )
		{
			AggressorInfo info;

			if ( m_pool.size > 0 )
			{
				info = m_pool.poll();

				info.m_attacker = attacker;
				info.m_defender = defender;

				info.m_can_report_murder = criminal;
				info.m_criminal_aggression = criminal;

				info.m_queued = false;

				info.refresh();
			}
			else
			{
				info = new AggressorInfo( attacker, defender, criminal );
			}

			return info;
		}

		public void free()
		{
			if ( m_queued )
			{
				return;
			}

			m_queued = true;
			m_pool.offer( this );
		}

		private AggressorInfo( Mobile attacker, Mobile defender, bool criminal )
		{
			m_attacker = attacker;
			m_defender = defender;

			m_can_report_murder = criminal;
			m_criminal_aggression = criminal;

			refresh();
		}

		private static TimeSpan m_expire_delay = TimeSpan.FromMinutes( 2.0 );

		public static TimeSpan expire_delay
		{
			get{ return m_expire_delay; }
			set{ m_expire_delay = value; }
		}

		public static void dump_access()
		{
			using ( StreamWriter op = new StreamWriter( "warnings.log", true ) )
			{
				op.WriteLine( "Warning: Access to queued AggressorInfo:" );
				op.WriteLine( new System.Diagnostics.StackTrace() );
				op.WriteLine();
				op.WriteLine();
			}
		}

		public bool expired
		{
			get
			{
				if ( m_queued )
				{
					dump_access();
				}

				return ( m_attacker.Deleted || m_defender.Deleted || DateTime.Now >= (m_last_combat_time + m_expire_delay) );
			}
		}

		public bool criminal_aggression
		{
			get
			{
				if ( m_queued )
				{
					dump_access();
				}

				return m_criminal_aggression;
			}
			set
			{
				if ( m_queued )
				{
					dump_access();
				}

				m_criminal_aggression = value;
			}
		}

		public Mobile attacker
		{
			get
			{
				if ( m_queued )
				{
					dump_access();
				}

				return m_attacker;
			}
		}

		public Mobile defender
		{
			get
			{
				if ( m_queued )
				{
					dump_access();
				}

				return m_defender;
			}
		}

		public DateTime last_combat_time
		{
			get
			{
				if ( m_queued )
				{
					dump_access();
				}

				return m_last_combat_time;
			}
		}

		public bool reported
		{
			get
			{
				if ( m_queued )
				{
					dump_access();
				}

				return m_reported;
			}
			set
			{
				if ( m_queued )
				{
					dump_access();
				}

				m_reported = value;
			}
		}

		public bool can_report_murder
		{
			get
			{
				if ( m_queued )
				{
					dump_access();
				}

				return m_can_report_murder;
			}
			set
			{
				if ( m_queued )
				{
					dump_access();
				}

				m_can_report_murder = value;
			}
		}

		public void refresh()
		{
			if ( m_queued )
			{
				dump_access();
			}

			m_last_combat_time = DateTime.Now;
			m_reported = false;
		}
	}
}