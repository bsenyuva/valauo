using System;
using System.Xml;
using Server;
using Server.Regions;
using Server.Mobiles;

namespace Server.Engines.Quests
{
	public class QuestOfferRegion : BaseRegion
	{
		private Type m_Quest;

		public Type Quest{ get{ return m_Quest ; } }

		public QuestOfferRegion( XmlElement xml, Map map, Region parent ) : base( xml, map, parent )
		{
			ReadType( xml["quest"], "type", ref m_Quest );
		}

		public override void OnEnter( Mobile m )
		{
			base.OnEnter( m );

			if ( m_Quest == null )
				return;

			PlayerMobile player = m as PlayerMobile;

			if ( player != null && player.Quest == null && QuestSystem.CanOfferQuest( m, m_Quest ) )
			{
				try
				{
					QuestSystem qs = (QuestSystem) Activator.CreateInstance( m_Quest, new object[] { player } );
					qs.SendOffer();
				}
				catch ( Exception ex )
				{
					stdout.printf( "Error creating quest {0}: {1}", m_Quest, ex );
				}
			}
		}
	}
}