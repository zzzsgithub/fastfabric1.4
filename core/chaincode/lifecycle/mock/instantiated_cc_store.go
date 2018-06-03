// Code generated by counterfeiter. DO NOT EDIT.
package mock

import (
	"sync"

	pb "github.com/hyperledger/fabric/protos/peer"
)

type InstantiatedChaincodeStore struct {
	ChaincodeDeploymentSpecStub        func(channelID, chaincodeName string) (*pb.ChaincodeDeploymentSpec, error)
	chaincodeDeploymentSpecMutex       sync.RWMutex
	chaincodeDeploymentSpecArgsForCall []struct {
		channelID     string
		chaincodeName string
	}
	chaincodeDeploymentSpecReturns struct {
		result1 *pb.ChaincodeDeploymentSpec
		result2 error
	}
	chaincodeDeploymentSpecReturnsOnCall map[int]struct {
		result1 *pb.ChaincodeDeploymentSpec
		result2 error
	}
	invocations      map[string][][]interface{}
	invocationsMutex sync.RWMutex
}

func (fake *InstantiatedChaincodeStore) ChaincodeDeploymentSpec(channelID string, chaincodeName string) (*pb.ChaincodeDeploymentSpec, error) {
	fake.chaincodeDeploymentSpecMutex.Lock()
	ret, specificReturn := fake.chaincodeDeploymentSpecReturnsOnCall[len(fake.chaincodeDeploymentSpecArgsForCall)]
	fake.chaincodeDeploymentSpecArgsForCall = append(fake.chaincodeDeploymentSpecArgsForCall, struct {
		channelID     string
		chaincodeName string
	}{channelID, chaincodeName})
	fake.recordInvocation("ChaincodeDeploymentSpec", []interface{}{channelID, chaincodeName})
	fake.chaincodeDeploymentSpecMutex.Unlock()
	if fake.ChaincodeDeploymentSpecStub != nil {
		return fake.ChaincodeDeploymentSpecStub(channelID, chaincodeName)
	}
	if specificReturn {
		return ret.result1, ret.result2
	}
	return fake.chaincodeDeploymentSpecReturns.result1, fake.chaincodeDeploymentSpecReturns.result2
}

func (fake *InstantiatedChaincodeStore) ChaincodeDeploymentSpecCallCount() int {
	fake.chaincodeDeploymentSpecMutex.RLock()
	defer fake.chaincodeDeploymentSpecMutex.RUnlock()
	return len(fake.chaincodeDeploymentSpecArgsForCall)
}

func (fake *InstantiatedChaincodeStore) ChaincodeDeploymentSpecArgsForCall(i int) (string, string) {
	fake.chaincodeDeploymentSpecMutex.RLock()
	defer fake.chaincodeDeploymentSpecMutex.RUnlock()
	return fake.chaincodeDeploymentSpecArgsForCall[i].channelID, fake.chaincodeDeploymentSpecArgsForCall[i].chaincodeName
}

func (fake *InstantiatedChaincodeStore) ChaincodeDeploymentSpecReturns(result1 *pb.ChaincodeDeploymentSpec, result2 error) {
	fake.ChaincodeDeploymentSpecStub = nil
	fake.chaincodeDeploymentSpecReturns = struct {
		result1 *pb.ChaincodeDeploymentSpec
		result2 error
	}{result1, result2}
}

func (fake *InstantiatedChaincodeStore) ChaincodeDeploymentSpecReturnsOnCall(i int, result1 *pb.ChaincodeDeploymentSpec, result2 error) {
	fake.ChaincodeDeploymentSpecStub = nil
	if fake.chaincodeDeploymentSpecReturnsOnCall == nil {
		fake.chaincodeDeploymentSpecReturnsOnCall = make(map[int]struct {
			result1 *pb.ChaincodeDeploymentSpec
			result2 error
		})
	}
	fake.chaincodeDeploymentSpecReturnsOnCall[i] = struct {
		result1 *pb.ChaincodeDeploymentSpec
		result2 error
	}{result1, result2}
}

func (fake *InstantiatedChaincodeStore) Invocations() map[string][][]interface{} {
	fake.invocationsMutex.RLock()
	defer fake.invocationsMutex.RUnlock()
	fake.chaincodeDeploymentSpecMutex.RLock()
	defer fake.chaincodeDeploymentSpecMutex.RUnlock()
	copiedInvocations := map[string][][]interface{}{}
	for key, value := range fake.invocations {
		copiedInvocations[key] = value
	}
	return copiedInvocations
}

func (fake *InstantiatedChaincodeStore) recordInvocation(key string, args []interface{}) {
	fake.invocationsMutex.Lock()
	defer fake.invocationsMutex.Unlock()
	if fake.invocations == nil {
		fake.invocations = map[string][][]interface{}{}
	}
	if fake.invocations[key] == nil {
		fake.invocations[key] = [][]interface{}{}
	}
	fake.invocations[key] = append(fake.invocations[key], args)
}
