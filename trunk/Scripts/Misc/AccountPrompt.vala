using System;
using Server;
using Server.Accounting;

namespace Server.Misc
{
	public class AccountPrompt
	{
		public static void Initialize()
		{
			if ( Accounts.Count == 0 && !Core.Service )
			{
				stdout.printf( "This server has no accounts." );
				Console.Write( "Do you want to create the owner account now? (y/n)" );

				if( Console.ReadKey( true ).Key == ConsoleKey.Y )
				{
					stdout.printf();

					Console.Write( "Username: " );
					string username = Console.ReadLine();

					Console.Write( "Password: " );
					string password = Console.ReadLine();

					Account a = new Account( username, password );
					a.AccessLevel = AccessLevel.Owner;

					stdout.printf( "Account created." );
				}
				else
				{
					stdout.printf();

					stdout.printf( "Account not created." );
				}
			}
		}
	}
}