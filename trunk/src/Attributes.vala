/***************************************************************************
 *                               Attributes.cs
 *                            -------------------
 *   begin                : May 1, 2002
 *   copyright            : (C) The RunUO Software Team
 *   email                : info@runuo.com
 *
 *   $Id: Attributes.cs 274 2007-12-17 20:41:34Z mark $
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
	[AttributeUsage( AttributeTargets.Property )]
	public class HueAttribute : Attribute
	{
		public HueAttribute()
		{
		}
	}

	[AttributeUsage( AttributeTargets.Property )]
	public class BodyAttribute : Attribute
	{
		public BodyAttribute()
		{
		}
	}

	[AttributeUsage( AttributeTargets.Class | AttributeTargets.Struct )]
	public class PropertyObjectAttribute : Attribute
	{
		public PropertyObjectAttribute()
		{
		}
	}

	[AttributeUsage( AttributeTargets.Class | AttributeTargets.Struct )]
	public class NoSortAttribute : Attribute
	{
		public NoSortAttribute()
		{
		}
	}

	[AttributeUsage( AttributeTargets.Method )]
	public class CallPriorityAttribute : Attribute
	{
		private int m_priority;

		public int Priority
		{
			get{ return m_priority; }
			set{ m_priority = value; }
		}

		public CallPriorityAttribute( int priority )
		{
			m_priority = priority;
		}
	}

	public class CallPriorityComparer : Comparable<MethodInfo>
	{
		public int compare( MethodInfo x, MethodInfo y )
		{
			if ( x == null && y == null )
				return 0;

			if ( x == null )
				return 1;

			if ( y == null )
				return -1;

			return get_priority( x ) - get_priority( y );
		}

		private int get_priority( MethodInfo mi )
		{
			object[] objs = mi.GetCustomAttributes( typeof( CallPriorityAttribute ), true );

			if ( objs == null )
				return 0;

			if ( objs.Length == 0 )
				return 0;

			CallPriorityAttribute attr = objs[0] as CallPriorityAttribute;

			if ( attr == null )
				return 0;

			return attr.Priority;
		}
	}

	[AttributeUsage( AttributeTargets.Class )]
	public class TypeAliasAttribute : Attribute
	{
		private string[] m_Aliases;

		public string[] Aliases
		{
			get
			{
				return m_Aliases;
			}
		}

		public TypeAliasAttribute( params string[] aliases )
		{
			m_Aliases = aliases;
		}
	}

	[AttributeUsage( AttributeTargets.Class | AttributeTargets.Struct )]
	public class ParsableAttribute : Attribute
	{
		public ParsableAttribute()
		{
		}
	}

	[AttributeUsage( AttributeTargets.Class | AttributeTargets.Struct | AttributeTargets.Enum )]
	public class CustomEnumAttribute : Attribute
	{
		private string[] m_Names;

		public string[] Names
		{
			get
			{
				return m_Names;
			}
		}

		public CustomEnumAttribute( string[] names )
		{
			m_Names = names;
		}
	}

	[AttributeUsage( AttributeTargets.Constructor )]
	public class ConstructableAttribute : Attribute
	{
		private AccessLevel m_AccessLevel;

		public AccessLevel AccessLevel
		{
			get { return m_AccessLevel; }
			set { m_AccessLevel = value; }
		}

		public ConstructableAttribute() : this( AccessLevel.Player )	//Lowest accesslevel for current functionality (Level determined by access to [add)
		{
		}

		public ConstructableAttribute( AccessLevel accessLevel )
		{
			m_AccessLevel = accessLevel;
		}
	}

	[AttributeUsage( AttributeTargets.Property )]
	public class CommandPropertyAttribute : Attribute
	{
		private AccessLevel m_read_level, m_write_level;
		private bool m_read_only;

		public AccessLevel read_level
		{
			get
			{
				return m_read_level;
			}
		}

		public AccessLevel write_level
		{
			get
			{
				return m_write_level;
			}
		}

		public bool ReadOnly
		{
			get
			{
				return m_read_only;
			}
		}

		public CommandPropertyAttribute( AccessLevel level, bool readOnly )
		{
			m_read_level = level;
			m_read_only = readOnly;
		}

		public CommandPropertyAttribute( AccessLevel level ) : this( level, level )
		{
		}

		public CommandPropertyAttribute( AccessLevel l_read_level, AccessLevel l_write_level )
		{
			m_read_level = l_read_level;
			m_write_level = l_write_level;
		}
	}
}
