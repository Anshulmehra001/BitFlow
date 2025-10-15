import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createStackNavigator } from '@react-navigation/stack';
import { StatusBar } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';

import StreamsScreen from './src/screens/StreamsScreen';
import CreateStreamScreen from './src/screens/CreateStreamScreen';
import QRScannerScreen from './src/screens/QRScannerScreen';
import SettingsScreen from './src/screens/SettingsScreen';
import StreamDetailsScreen from './src/screens/StreamDetailsScreen';
import { StreamProvider } from './src/context/StreamContext';
import { OfflineProvider } from './src/context/OfflineContext';
import { NotificationProvider } from './src/context/NotificationContext';

const Tab = createBottomTabNavigator();
const Stack = createStackNavigator();

function StreamsStack() {
  return (
    <Stack.Navigator>
      <Stack.Screen 
        name="StreamsList" 
        component={StreamsScreen} 
        options={{ title: 'My Streams' }}
      />
      <Stack.Screen 
        name="StreamDetails" 
        component={StreamDetailsScreen} 
        options={{ title: 'Stream Details' }}
      />
      <Stack.Screen 
        name="CreateStream" 
        component={CreateStreamScreen} 
        options={{ title: 'Create Stream' }}
      />
      <Stack.Screen 
        name="QRScanner" 
        component={QRScannerScreen} 
        options={{ title: 'Scan QR Code' }}
      />
    </Stack.Navigator>
  );
}

function TabNavigator() {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        tabBarIcon: ({ focused, color, size }) => {
          let iconName: any;

          if (route.name === 'Streams') {
            iconName = 'account-balance-wallet';
          } else if (route.name === 'Settings') {
            iconName = 'settings';
          } else {
            iconName = 'help';
          }

          return <MaterialIcons name={iconName} size={size} color={color} />;
        },
        tabBarActiveTintColor: '#007AFF',
        tabBarInactiveTintColor: 'gray',
      })}
    >
      <Tab.Screen 
        name="Streams" 
        component={StreamsStack} 
        options={{ headerShown: false }}
      />
      <Tab.Screen name="Settings" component={SettingsScreen} />
    </Tab.Navigator>
  );
}

export default function App() {
  return (
    <NotificationProvider>
      <OfflineProvider>
        <StreamProvider>
          <NavigationContainer>
            <StatusBar barStyle="default" />
            <TabNavigator />
          </NavigationContainer>
        </StreamProvider>
      </OfflineProvider>
    </NotificationProvider>
  );
}