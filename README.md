
# react-native-character-view

## What is this?

A view component to render chinese characters. Currently supports stroke order animations. Quiz functionality coming soon.

Huge shout out to @skishore for his awesome work on [https://github.com/skishore/makemeahanzi](makemeahanzi)! This project would not be possible without his stroke order data.

## Getting started

`$ npm install react-native-character-view --save`

### Mostly automatic installation

`$ react-native link react-native-character-view`

### Manual installation


#### iOS

1. In XCode, in the project navigator, right click `Libraries` ➜ `Add Files to [your project's name]`
2. Go to `node_modules` ➜ `react-native-character-view` and add `RNCharacterView.xcodeproj`
3. In XCode, in the project navigator, select your project. Add `libRNCharacterView.a` to your project's `Build Phases` ➜ `Link Binary With Libraries`
4. Run your project (`Cmd+R`)<

#### Android

1. Open up `android/app/src/main/java/[...]/MainActivity.java`
  - Add `import com.reactlibrary.RNCharacterViewPackage;` to the imports at the top of the file
  - Add `new RNCharacterViewPackage()` to the list returned by the `getPackages()` method
2. Append the following lines to `android/settings.gradle`:
  	```
  	include ':react-native-character-view'
  	project(':react-native-character-view').projectDir = new File(rootProject.projectDir, 	'../node_modules/react-native-character-view/android')
  	```
3. Insert the following lines inside the dependencies block in `android/app/build.gradle`:
  	```
      compile project(':react-native-character-view')
  	```

#### Windows
[Read it! :D](https://github.com/ReactWindows/react-native)

1. In Visual Studio add the `RNCharacterView.sln` in `node_modules/react-native-character-view/windows/RNCharacterView.sln` folder to their solution, reference from their app.
2. Open up your `MainPage.cs` app
  - Add `using Cl.Json.RNCharacterView;` to the usings at the top of the file
  - Add `new RNCharacterViewPackage()` to the `List<IReactPackage>` returned by the `Packages` method
      

## Usage
```javascript
import RNCharacterView from 'react-native-character-view';
import { NativeModules } from 'react-native'

// This will be hidden in future releases
const CharacterViewManager = NativeModules.RNCharacterViewManager;

render() {
    <CharacterView
	character={character}
	ref="characterView"
	style={{flex: 1}}
    />
}
```
Animate the strokes by calling 

```javascript
 CharacterViewManager.animateStrokes();
```

##License

GNU
