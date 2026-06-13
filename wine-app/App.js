import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createStackNavigator } from '@react-navigation/stack';
import { StatusBar } from 'expo-status-bar';
import { Text } from 'react-native';

import ScannerScreen from './screens/ScannerScreen';
import WineDetailScreen from './screens/WineDetailScreen';
import WineLogScreen from './screens/WineLogScreen';

const Tab = createBottomTabNavigator();
const Stack = createStackNavigator();

function ScannerStack() {
  return (
    <Stack.Navigator
      screenOptions={{
        headerStyle: { backgroundColor: '#6B2737' },
        headerTintColor: '#fff',
        headerTitleStyle: { fontWeight: '700' },
      }}
    >
      <Stack.Screen
        name="Scanner"
        component={ScannerScreen}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="WineDetail"
        component={WineDetailScreen}
        options={{ title: 'Vininfo', headerBackTitle: 'Tillbaka' }}
      />
    </Stack.Navigator>
  );
}

export default function App() {
  return (
    <NavigationContainer>
      <StatusBar style="light" />
      <Tab.Navigator
        screenOptions={({ route }) => ({
          tabBarIcon: ({ color, size }) => {
            const icons = { Skanna: '📷', 'Min logg': '📒' };
            return <Text style={{ fontSize: size - 4 }}>{icons[route.name]}</Text>;
          },
          tabBarActiveTintColor: '#6B2737',
          tabBarInactiveTintColor: '#aaa',
          tabBarStyle: { borderTopColor: '#e8e0d8', backgroundColor: '#fff' },
          tabBarLabelStyle: { fontSize: 12, fontWeight: '600' },
          headerStyle: { backgroundColor: '#6B2737' },
          headerTintColor: '#fff',
          headerTitleStyle: { fontWeight: '700' },
        })}
      >
        <Tab.Screen
          name="Skanna"
          component={ScannerStack}
          options={{ headerShown: false }}
        />
        <Tab.Screen
          name="Min logg"
          component={WineLogScreen}
          options={{ title: 'Min vinlogg' }}
        />
      </Tab.Navigator>
    </NavigationContainer>
  );
}
